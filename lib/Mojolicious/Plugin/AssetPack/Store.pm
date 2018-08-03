package Mojolicious::Plugin::AssetPack::Store;
use Mojo::Base 'Mojolicious::Static';

use Mojo::File 'path';
use Mojo::Loader 'data_section';
use Mojo::Template;
use Mojo::URL;
use Mojolicious::Types;
use Mojolicious::Plugin::AssetPack::Asset;
use Mojolicious::Plugin::AssetPack::Util qw(diag checksum has_ro DEBUG);

use constant CACHE_DIR => 'cache';

# MOJO_ASSETPACK_DB_FILE is used in tests
use constant DB_FILE => $ENV{MOJO_ASSETPACK_DB_FILE} || 'assetpack.db';
our %DB_KEYS = map { $_ => 1 } qw(checksum format minified rel);
our %FALLBACK_TEMPLATES = %{data_section(__PACKAGE__)};

for my $name (keys %FALLBACK_TEMPLATES) {
  my $text = delete $FALLBACK_TEMPLATES{$name};
  $name =~ m!(\w+)\.ep$!;
  $FALLBACK_TEMPLATES{$1} = Mojo::Template->new->parse($text)->prepend('my ($c, $assets) = @_;');
}

has asset_class        => 'Mojolicious::Plugin::AssetPack::Asset';
has default_headers    => sub { +{"Cache-Control" => "max-age=31536000"} };
has fallback_headers   => sub { +{"Cache-Control" => "max-age=60"} };
has fallback_templates => sub { +{%FALLBACK_TEMPLATES} };

has _types => sub {
  my $t = Mojolicious::Types->new;
  $t->type(eot   => 'application/vnd.ms-fontobject');
  $t->type(otf   => 'application/font-otf');
  $t->type(ttf   => 'application/font-ttf');
  $t->type(woff2 => 'application/font-woff2');
  delete $t->mapping->{$_} for qw(atom bin htm html txt xml zip);
  $t;
};

has_ro 'ua';

has_ro _db => sub {
  my $self = shift;
  my ($db, $key, $url) = ({});
  for my $path (reverse map { path($_, DB_FILE) } @{$self->paths}) {
    open my $DB, '<', $path or next;
    while (my $line = <$DB>) {
      ($key, $url) = ($1, $2) if $line =~ /^\[([\w-]+):(.+)\]$/;
      $db->{$url}{$key}{$1} = $2 if $key and $line =~ /^(\w+)=(.*)/ and $DB_KEYS{$1};
    }
  }
  return $db;
};

sub asset {
  my ($self, $urls, $paths) = @_;
  my $asset;

  for my $url (ref $urls eq 'ARRAY' ? @$urls : ($urls)) {
    return $self->_asset_from_helper(Mojo::URL->new($url)) if $url =~ m!^helper://!;
    for my $path (@{$paths || $self->paths}) {
      next unless $path =~ m!^https?://!;
      my $abs = Mojo::URL->new($path);
      $abs->path->merge($url);
      return $asset if $asset = $self->_already_downloaded($abs);
    }
  }

  for my $url (ref $urls eq 'ARRAY' ? @$urls : ($urls)) {
    return $asset if $url =~ m!^https?://! and $asset = $self->_download(Mojo::URL->new($url));

    for my $path (@{$paths || $self->paths}) {
      if ($path =~ m!^https?://!) {
        my $abs = Mojo::URL->new($path);
        $abs->path->merge($url);
        return $asset if $asset = $self->_download($abs);
      }
      else {
        local $self->{paths} = [$path];
        next unless $asset = $self->file($url);
        return $self->asset_class->new(url => $url, content => $asset);
      }
    }
  }

  return undef;
}

sub load {
  my ($self, $attrs) = @_;
  my $db_attr = $self->_db_get($attrs) or return undef;
  my @rel     = $self->_cache_path($attrs);
  my $asset   = $self->asset(join '/', @rel);

  return undef unless $asset;
  return undef unless $db_attr->{checksum} eq $attrs->{checksum};
  diag 'Load "%s" = 1', $asset->path || $asset->url if DEBUG;
  return $asset;
}

sub persist {
  my $self    = shift;
  my $db      = $self->_db;
  my $path    = path($self->paths->[0], DB_FILE);
  my @db_keys = sort keys %DB_KEYS;
  my $DB;

  unless (open $DB, '>', $path) {
    diag 'Save "%s" = 0 (%s)', $path, $! if DEBUG;
    return $self;
  }

  diag 'Save "%s" = 1', $path if DEBUG;
  for my $url (sort keys %$db) {
    for my $key (sort keys %{$db->{$url}}) {
      Carp::confess("Invalid key '$key'. Need to be [a-z-].") unless $key =~ /^[\w-]+$/;
      printf $DB "[%s:%s]\n", $key, $url;
      for my $attr (@db_keys) {
        next unless defined $db->{$url}{$key}{$attr};
        printf $DB "%s=%s\n", $attr, $db->{$url}{$key}{$attr};
      }
    }
  }

  return $self;
}

sub save {
  my ($self, $ref, $attrs) = @_;
  my $path = path($self->paths->[0], $self->_cache_path($attrs));
  my $dir = $path->dirname;

  # Do not care if this fail. Can fallback to temp files.
  mkdir $dir if !-d $dir and -w $dir->dirname;
  diag 'Save "%s" = %s', $path, -d $dir ? 1 : 0 if DEBUG;

  return $self->asset_class->new(%$attrs, content => $$ref) unless -w $dir;

  $path->spurt($$ref);
  $self->_db_set(%$attrs);
  return $self->asset_class->new(%$attrs, path => $path);
}

sub serve_asset {
  my ($self, $c, $asset) = @_;
  my $dh = $self->default_headers;
  my $h  = $c->res->headers;

  $h->header($_ => $dh->{$_}) for keys %$dh;
  $h->content_type($self->_types->type($asset->format) || 'application/octet-stream');

  if (my $renderer = $asset->renderer) {
    $renderer->($asset, $c);
  }
  else {
    $self->SUPER::serve_asset($c, $asset->can('asset') ? $asset->asset : $asset);
  }

  return $self;
}

sub serve_fallback_for_assets {
  my ($self, $c, $topic, $assets) = @_;
  my $fh     = $self->fallback_headers;
  my $format = $topic =~ m!\.(\w+)$! ? $1 : 'css';
  my $h      = $c->res->headers;

  $h->header($_ => $fh->{$_}) for keys %$fh;
  $h->content_type($self->_types->type($format) || 'application/octet-stream');

  if (my $template = $self->fallback_templates->{$format}) {
    $c->render(data => $template->process($c, $assets));
  }
  elsif (@$assets == 1) {
    my $url = $assets->[0]->url_for($c);
    $url->path->[-1] = $topic;
    $c->redirect_to($url);
  }
  else {
    $c->render(text => "// Invalid checksum for topic '$topic'\n", status => 404);
  }

  return $self;
}

sub _already_downloaded {
  my ($self, $url) = @_;
  my $asset = $self->asset_class->new(url => "$url");
  my @dirname = $self->_url2path($url, '');
  my $basename = pop @dirname;

  for my $path (map { path $_, @dirname } @{$self->paths}) {

    # URL with extension
    my $file = $path->child($basename);
    return $asset->format($1)->path($file) if -e $file and $file =~ m!\.(\w+)$!;

    # URL without extension - https://fonts.googleapis.com/css?family=Roboto
    for my $file ($path->list->each) {
      next unless $file->basename =~ /^$basename(\w+)$/;
      return $asset->format($1)->path($file);
    }
  }

  return undef;
}

sub _asset_from_helper {
  my ($self, $url) = @_;
  my $app    = $self->ua->server->app;
  my $args   = $url->query->to_hash;
  my $helper = $app->renderer->helpers->{$url->host};
  my $output = $app->build_controller->$helper($url->path->[0], $args);

  die "[AssetPack] Unknown helper @{[$url->host]}" unless $helper;
  my $asset = $self->asset_class->new(url => $url, ref $output ? %$output : (content => $output));

  $asset->format($args->{format}) if $args->{format};
  $asset;
}

sub _cache_path {
  my ($self, $attrs) = @_;
  return (
    CACHE_DIR, sprintf '%s-%s.%s%s',
    $attrs->{name},
    checksum($attrs->{url}),
    $attrs->{minified} ? 'min.' : '',
    $attrs->{format}
  );
}

sub _db_get {
  my ($self, $attrs) = @_;
  my $db = $self->_db;
  return undef unless my $data = $db->{$attrs->{url}};
  return undef unless $data = $data->{$attrs->{key}};
  return {%$attrs, %$data};
}

sub _db_set {
  return if $ENV{MOJO_ASSETPACK_LAZY};
  my ($self, %attrs) = @_;
  my ($key,  $url)   = @attrs{qw(key url)};
  $self->_db->{$url}{$key} = {%attrs};
}

sub _download {
  my ($self, $url) = @_;
  my %attrs = (url => $url->clone);
  my ($asset, $path);

  if ($attrs{url}->host eq 'local') {
    my $base = $self->ua->server->url;
    $url = $url->clone->scheme($base->scheme)->host_port($base->host_port);
  }

  return $asset if $attrs{url}->host ne 'local' and $asset = $self->_already_downloaded($url);

  my $tx = $self->ua->get($url);
  my $h  = $tx->res->headers;

  if (my $err = $tx->error) {
    $self->_log->warn("[AssetPack] Unable to download $url: $err->{message}");
    return undef;
  }

  my $ct = $h->content_type || '';
  if ($ct ne 'text/plain') {
    $ct =~ s!;.*$!!;
    $attrs{format} = $self->_types->detect($ct)->[0];
  }

  $attrs{format} ||= $tx->req->url->path->[-1] =~ /\.(\w+)$/ ? $1 : 'bin';

  if ($attrs{url}->host ne 'local') {
    $path = path($self->paths->[0], $self->_url2path($attrs{url}, $attrs{format}));
    $self->_log->info(qq(Caching "$url" to "$path".));
    $path->dirname->make_path unless -d $path->dirname;
    $path->spurt($tx->res->body);
  }

  $attrs{url} = "$attrs{url}";
  return $self->asset_class->new(%attrs, path => $path) if $path;
  return $self->asset_class->new(%attrs)->content($tx->res->body);
}

sub _log { shift->ua->server->app->log }

sub _url2path {
  my ($self, $url, $format) = @_;
  my $query = $url->query->to_string;
  my @path;

  push @path, $url->host;
  push @path, @{$url->path};

  $query =~ s!\W!_!g;
  $path[-1] .= "_$query.$format" if $query;

  return CACHE_DIR, @path;
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::AssetPack::Store - Storage for assets

=head1 SYNOPSIS

  use Mojolicious::Lite;

  # Load plugin and pipes in the right order
  plugin AssetPack => {pipes => \@pipes};

  # Change where assets can be found
  app->asset->store->paths([
    app->home->rel_file("some/directory"),
    "/some/other/directory",
  ]);

  # Change where assets are stored
  app->asset->store->paths->[0] = app->home->rel_file("some/directory");

  # Define asset
  app->asset->process($moniker => @assets);

  # Retrieve a Mojolicious::Plugin::AssetPack::Asset object
  my $asset = app->asset->store->asset("some/file.js");

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Store> is an object to manage cached
assets on disk.

The idea is that a L<Mojolicious::Plugin::AssetPack::Pipe> object can store
an asset after it is processed. This will speed up development, since only
changed assets will be processed and it will also allow processing tools to
be optional in production environment.

This module will document meta data about each asset which is saved to disk, so
it can be looked up later as a unique item using L</load>.

=head1 ATTRIBUTES

L<Mojolicious::Plugin::AssetPack::Store> inherits all attributes from
L<Mojolicious::Static> implements the following new ones.

=head2 asset_class

  $str = $self->asset_class;
  $self = $self->asset_class("Mojolicious::Plugin::AssetPack::Asset");

Holds the classname of which new assets will be constructed from.

=head2 default_headers

  $hash_ref = $self->default_headers;
  $self = $self->default_headers({"Cache-Control" => "max-age=31536000"});

Used to set headers used by L</serve_asset>.

=head2 fallback_headers

  $hash_ref = $self->fallback_headers;
  $self = $self->fallback_headers({"Cache-Control" => "max-age=300"});

Used to set headers used by L</serve_fallback_for_assets>.

This is currently an EXPERIMENTAL feature.

=head2 fallback_templates

  $hash_ref = $self->fallback_templates;
  $self = $self->fallback_templates->{"css"} = Mojo::Template->new;

Used to set up templates used by L</serve_fallback_for_assets>.

This is currently an EXPERIMENTAL feature.

=head2 paths

  $paths = $self->paths;
  $self = $self->paths([$app->home->rel_file("assets")]);

See L<Mojolicious::Static/paths> for details.

=head2 ua

  $ua = $self->ua;

See L<Mojolicious::Plugin::AssetPack/ua>.

=head1 METHODS

L<Mojolicious::Plugin::AssetPack::Store> inherits all attributes from
L<Mojolicious::Static> implements the following new ones.

=head2 asset

  $asset = $self->asset($url, $paths);

Returns a L<Mojolicious::Plugin::AssetPack::Asset> object or undef unless
C<$url> can be found in C<$paths>. C<$paths> default to
L<Mojolicious::Static/paths>. C<$paths> and C<$url> can be...

=over 2

=item * helper://some.mojo.helper/some_identifier?format=css

Will call a helper registered under the name C<csome.mojo.helper>, with the
query parameters as arguments. Example:

  $output = $c->some->mojo->helper(some_identifier => {format => "css"});

C<$output> can be a scalar containing the asset content or a hash-ref with
arguments passed on to L<Mojolicious::Plugin::AssetPack::Asset>. Note that
C<format> need to be present in the URL or the returning hash-ref for this
to work.

This feature is currently EXPERIMENTAL. Let me know if you use it/find it
interesting.

=item * http://example.com/foo/bar

An absolute URL will be downloaded from web, unless the host is "local":
"local" is a special host which will run the request through the current
L<Mojolicious> application.

=item * foo/bar

An relative URL will be looked up using L<Mojolicious::Static/file>.

=back

Note that assets from web will be cached locally, which means that you need to
delete the files on disk to download a new version.

=head2 load

  $bool = $self->load($asset, \%attr);

Used to load an existing asset from disk. C<%attr> will override the
way an asset is looked up. The example below will ignore
L<minified|Mojolicious::Plugin::AssetPack::Asset/minified> and rather use
the value from C<%attr>:

  $bool = $self->load($asset, {minified => $bool});

=head2 persist

  $self = $self->persist;

Used to save the internal state of the store to disk.

This method is EXPERIMENTAL, and may change without warning.

=head2 save

  $bool = $self->save($asset, \%attr);

Used to save an asset to disk. C<%attr> are usually the same as
L<Mojolicious::Plugin::AssetPack::Asset/TO_JSON> and used to document metadata
about the C<$asset> so it can be looked up using L</load>.

=head2 serve_asset

  $self = $self->serve_asset($c, $asset);

Override L<Mojolicious::Static/serve_asset> with the functionality to set
response headers first, from L</default_headers>.

Will call L<Mojolicious::Plugin::AssetPack::Asset/render> if available, after
setting Content-Type header and other L</default_headers>.

=head2 serve_fallback_for_assets

  $self = $self->serve_fallback_for_assets($c, $topic, $assets);

Used to serve a fallback response for given C<$topic> and a
L<Mojo::Collection> of C<Mojolicious::Plugin::AssetPack::Asset> objects.

Will set the headers in L</fallback_headers> and then either render either a
template matching the extension from C<$topic> from L</fallback_templates>, a
302 redirect to the actual asset, or a 404 Not Found.

This is currently an EXPERIMENTAL feature.

=head1 SEE ALSO

L<Mojolicious::Plugin::AssetPack>.

=cut

__DATA__
@@ fallback.css.ep
% for my $asset (@$assets) {
@import "<%= $asset->url_for($c) %>";
% }
@@ fallback.js.ep
% use Mojo::JSON 'to_json';
(function(w,d,a,b){
var c=function(){
var t=d.createElement("script");
t.src=b.shift();
if(b.length) t.addEventListener("load",c);
a.parentNode.insertBefore(t,a);
};
c();
})(window,document,document.getElementsByTagName("script")[0],<%= to_json([map { $_->url_for($c) } @$assets]) %>);
