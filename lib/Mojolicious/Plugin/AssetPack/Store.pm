package Mojolicious::Plugin::AssetPack::Store;
use Mojo::Base 'Mojolicious::Static';
use Mojo::Util 'spurt';
use Mojo::URL;
use Mojolicious::Types;
use Mojolicious::Plugin::AssetPack::Asset;
use Mojolicious::Plugin::AssetPack::Util qw(diag checksum has_ro DEBUG);
use File::Basename 'dirname';
use File::Path 'make_path';

# MOJO_ASSETPACK_DB_FILE is used in tests
use constant DB_FILE_NAME => $ENV{MOJO_ASSETPACK_DB_FILE} || 'assetpack.db';

has default_headers => sub { +{"Cache-Control" => "max-age=31536000"} };

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
  for my $path (reverse @{$self->_files(DB_FILE_NAME, sub {-r})}) {
    open my $DB, '<', $path or next;
    while (my $line = <$DB>) {
      ($key, $url) = ($1, $2) if $line =~ /^\[([\w-]+):(.+)\]$/;
      $db->{$url}{$key}{$1} = $2 if $key and $line =~ /^(\w+)=(.*)/;
    }
  }
  return $db;
};

sub asset {
  my ($self, $urls, $paths) = @_;
  my $asset;

  for my $url (ref $urls ? @$urls : ($urls)) {
    for my $path (@{$paths || $self->paths}) {
      next unless $path =~ m!^https?://!;
      my $abs = Mojo::URL->new($path);
      $abs->path->merge($url);
      return $asset if $asset = $self->_already_downloaded($abs);
    }
  }

  for my $url (ref $urls ? @$urls : ($urls)) {
    return $asset
      if $url =~ m!^https?://! and $asset = $self->_download(Mojo::URL->new($url));

    for my $path (@{$paths || $self->paths}) {
      if ($path =~ m!^https?://!) {
        my $abs = Mojo::URL->new($path);
        $abs->path->merge($url);
        return $asset if $asset = $self->_download($abs);
      }
      else {
        local $self->{paths} = [$path];
        next unless $asset = $self->file($url);
        my $attrs = $self->_db_get({key => 'original', url => $url}) || {url => $url};
        return Mojolicious::Plugin::AssetPack::Asset->new(%$attrs, content => $asset);
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

sub save {
  my ($self, $ref, $attrs) = @_;
  my $path = File::Spec->catfile($self->paths->[0], $self->_cache_path($attrs));
  my $dir = dirname $path;

  # Do not care if this fail. Can fallback to temp files.
  mkdir $dir if !-d $dir and -w dirname $dir;
  diag 'Save "%s" = %s', $path, -d $dir ? 1 : 0 if DEBUG;

  return Mojolicious::Plugin::AssetPack::Asset->new(%$attrs, content => $$ref)
    unless -w $dir;
  $self->_db_set($attrs);
  spurt $$ref, $path;
  return Mojolicious::Plugin::AssetPack::Asset->new(%$attrs, path => $path);
}

sub serve_asset {
  my ($self, $c, $asset) = @_;
  my $d  = $self->default_headers;
  my $h  = $c->res->headers;
  my $ct = $self->_types->type($asset->format);

  if ($ct) {
    $h->header($_ => $d->{$_}) for keys %$d;
    $h->content_type($ct);
    $self->SUPER::serve_asset($c, $asset->can('asset') ? $asset->asset : $asset);
  }
  else {
    $h->content_type('text/css');
    $c->render(text =>
        qq(body:before{content:'"@{[$asset->url]}" is not processed.';font-size:32px;position:absolute;top:0;left:0;background:red;color:white;}\n)
    );
  }

  return $self;
}

sub _already_downloaded {
  my ($self, $url) = @_;
  my $attrs = $self->_db_get({key => 'original', url => $url}) or return undef;
  my $asset;

  if ($attrs->{rel} and $asset = $self->asset($attrs->{rel})) {
    $asset->{url} = $url;
    $asset->{format} ||= $attrs->{format} if $attrs->{format};
    $asset->{mtime}  ||= $attrs->{mtime}  if $attrs->{mtime};
    diag 'Already downloaded: %s', $asset->url if DEBUG;
    return $asset;
  }

  return undef;
}

sub _cache_path {
  my ($self, $attrs) = @_;
  return (
    'cache', sprintf '%s-%s.%s%s',
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
  my ($self, $attrs) = @_;
  my $db   = $self->_db;
  my $path = $self->_files(DB_FILE_NAME)->[0];
  my $data = $db->{$attrs->{url}}{$attrs->{key}} ||= {};

  %$data = %$attrs;
  if (open my $DB, '>', $path) {
    diag 'Save "%s" = 1', $path if DEBUG;
    for my $url (sort keys %$db) {
      for my $key (sort keys %{$db->{$url}}) {
        delete $db->{$url}{$key}{$_} for qw(key name url);
        next unless my @attrs = keys %{$db->{$url}{$key}};
        Carp::confess("Invalid key '$key'. Need to be [a-z-].") unless $key =~ /^[\w-]+$/;
        printf $DB "[%s:%s]\n", $key, $url;
        for my $attr (sort @attrs) {
          next unless defined $db->{$url}{$key}{$attr};
          printf $DB "%s=%s\n", $attr, $db->{$url}{$key}{$attr};
        }
      }
    }
  }
  else {
    diag 'Save "%s" = 0 (%s)', $path, $! if DEBUG;
  }
}

sub _download {
  my ($self, $url) = @_;
  my $req_url = $url;
  my ($asset, $attrs, $path);

  if ($req_url->host eq 'local') {
    my $base = $self->ua->server->url;
    $req_url = $url->clone->scheme($base->scheme)->host_port($base->host_port);
  }

  return $asset if $asset = $self->_already_downloaded($url);

  my $rel = _rel($url);
  my $tx  = $self->ua->get($req_url);
  my $h   = $tx->res->headers;

  if ($tx->error) {
    $self->ua->server->app->log->warn(
      "[AssetPack] Unable to download $req_url: @{[$tx->error->{message}]}");
    return undef;
  }

  if ($url->host ne 'local') {
    $path = File::Spec->catdir($self->paths->[0], split '/', $rel);
    $self->ua->server->app->log->info(qq(Caching "$req_url" to "$path".));
    make_path(dirname $path) unless -d dirname $path;
    spurt $tx->res->body, $path;
  }

  if (my $lm = $h->last_modified) {
    $attrs->{mtime} = Mojo::Date->new($lm)->epoch;
  }
  if (my $ct = $h->content_type) {
    $ct =~ s!;.*$!!;
    $attrs->{format} = $self->_types->detect($ct)->[0];
  }

  $attrs->{format} ||= $tx->req->url->path->[-1] =~ /\.(\w+)$/ ? $1 : undef;
  @$attrs{qw(key rel url)} = ('original', $rel, $url->to_string);
  $self->_db_set($attrs);
  return Mojolicious::Plugin::AssetPack::Asset->new(%$attrs, path => $path) if $path;
  return Mojolicious::Plugin::AssetPack::Asset->new(%$attrs)->content($tx->res->body);
}

sub _files {
  my ($self, $name, $check) = @_;
  my @files = map { File::Spec->catfile($_, split '/', $name) } @{$self->paths};
  return [grep $check, @files] if $check;
  return \@files;
}

sub _rel {
  local $_ = shift->clone->scheme(undef)->to_string;
  s![^\w\.\/-]!_!g;
  s!^\/+!!;
  s!\/+$!!;
  "cache/$_";
}

sub _reset {
  my ($self, $args) = @_;
  return unless $args->{unlink};
  local $! = 0;
  my $file = $self->_files(DB_FILE_NAME)->[0];
  unlink $file;
  diag 'unlink %s = %s', $file, $! || '1' if DEBUG;
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
    app->home->rel_dir("some/directory"),
    "/some/other/directory",
  ]);

  # Change where assets are stored
  app->asset->store->paths->[0] = app->home->rel_dir("some/directory");

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

=head2 default_headers

  $hash_ref = $self->default_headers;
  $self = $self->default_headers({"Cache-Control" => "max-age=31536000"});

Used to set default headers used by L</serve_asset>.

=head2 ua

  $ua = $self->ua;

See L<Mojolicious::Plugin::AssetPack/ua>.

=head1 METHODS

L<Mojolicious::Plugin::AssetPack::Store> inherits all attributes from
L<Mojolicious::Static> implements the following new ones.

=head2 asset

  $asset = $self->asset($url, $paths);

Retuns a L<Mojolicious::Plugin::AssetPack::Asset> object or undef unless
C<$url> can be found in C<$paths>. C<$paths> default to
L<Mojolicious::Static/paths>. C<$paths> and C<$url> can be...

=over 2

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

=head2 save

  $bool = $self->save($asset, \%attr);

Used to save an asset to disk. C<%attr> are usually the same as
L<Mojolicious::Plugin::AssetPack::Asset/TO_JSON> and used to document metadata
about the C<$asset> so it can be looked up using L</load>.

=head2 serve_asset

Override L<Mojolicious::Static/serve_asset> with the functionality to set
response headers first, from L</default_headers>.

=head1 SEE ALSO

L<Mojolicious::Plugin::AssetPack>.

=cut
