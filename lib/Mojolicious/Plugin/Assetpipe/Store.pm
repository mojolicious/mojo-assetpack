package Mojolicious::Plugin::Assetpipe::Store;
use Mojo::Base 'Mojolicious::Static';
use Mojo::JSON;
use Mojo::Util qw(slurp spurt);
use Mojo::URL;
use Mojolicious::Plugin::Assetpipe::Util qw(diag checksum has_ro DEBUG);
use File::Basename 'dirname';
use File::Path 'make_path';

has default_headers => sub { +{"Cache-Control" => "max-age=31536000"} };

# MOJO_ASSETPIPE_DB_FILE is used in tests
has _file => sub {
  File::Spec->catfile(shift->paths->[0], $ENV{MOJO_ASSETPIPE_DB_FILE} || 'assetpipe.db');
};

has _content_type => sub {
  return {css => 'text/css', js => 'application/javascript'};
};

has_ro 'ua';

sub attrs {
  my ($self, $attrs) = @_;
  my $db = $self->_db('all');
  return unless $db->{$attrs->{url}};
  return $db->{$attrs->{url}}{$attrs->{key}};
}

sub file {
  my ($self, $rel) = @_;
  my $f;

  return $self->_download(Mojo::URL->new($rel)) if $rel =~ m!^https?://!;

  for my $p (@{ref $_[-1] eq 'ARRAY' ? pop : $self->paths}) {
    if ($p =~ m!^https?://!) {
      my $url = Mojo::URL->new($p);
      $url->path->merge($rel);
      return $f if $f = $self->_download($url);
    }
    else {
      local $self->{paths} = [$p];
      return $f if $f = $self->SUPER::file($rel);
    }
  }

  return undef;
}

sub load {
  my ($self, $attrs) = @_;
  my $db_attr = $self->attrs($attrs) or return undef;
  my @rel     = $self->_cache_path($attrs);
  my $file    = $self->file(join '/', @rel);

  return undef unless $file;
  return undef unless $db_attr->{checksum} eq $attrs->{checksum};
  diag 'Load "%s" = 1', eval { $file->path } || join('/', @rel) if DEBUG;
  return $file;
}

sub save {
  my ($self, $ref, $attrs) = @_;
  my $path = File::Spec->catfile($self->paths->[0], $self->_cache_path($attrs));
  my $dir = dirname $path;

  # Do not care if this fail. Can fallback to temp files.
  mkdir $dir if !-d $dir and -w dirname $dir;
  diag 'Save "%s" = %s', $path, -d $dir ? 1 : 0 if DEBUG;

  return Mojo::Asset::Memory->new->add_chunk($$ref) unless -w $dir;
  $self->_db(save => $attrs);
  spurt $$ref, $path;
  return Mojo::Asset::File->new(path => $path);
}

sub serve_asset {
  my ($self, $c, $asset) = @_;
  my $d  = $self->default_headers;
  my $h  = $c->res->headers;
  my $ct = $self->_content_type->{$asset->format};

  unless ($ct) {
    $h->content_type('text/css');
    $c->render(text =>
        qq(body:before{content:'"@{[$asset->url]}" is not processed.';font-size:32px;position:absolute;top:0;left:0;background:red;color:white;}\n)
    );
    return $self;
  }

  $h->header($_ => $d->{$_}) for keys %$d;
  $h->content_type($ct);
  $self->SUPER::serve_asset($c, $asset);
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

sub _db {
  my ($self, $action, $attrs) = @_;
  my ($data, $db);

  $db = $self->{_db}
    ||= -r $self->_file ? Mojo::JSON::decode_json(slurp $self->_file) : {};
  return $db if $action eq 'all';

  $data = $db->{$attrs->{url}}   ||= {};
  $data = $data->{$attrs->{key}} ||= {};

  if ($action eq 'save') {
    %$data = %$attrs;
    delete $data->{$_} for qw(key name url);
    diag 'Save "%s" = %s', $self->_file, -w $self->paths->[0] ? 1 : 0 if DEBUG;
    spurt Mojo::JSON::encode_json($db), $self->_file if -w $self->paths->[0];
  }

  return $data;
}

sub _download {
  my ($self, $url) = @_;
  my $rel = $url->clone->to_abs;
  my %attrs = (mtime => time);

  $rel->port(undef)->scheme(undef);
  $rel = $rel->to_string;
  $rel =~ s![^\w\.\/-]!_!g;
  $rel =~ s!^\/+!!;
  $rel =~ s!\/+$!!;
  $rel = "cache/$rel";

  if (my $file = $self->file($rel)) {
    diag 'Already downloaded: %s', $url if DEBUG;
    return $file;
  }

  my $app = $self->ua->server->app;
  my $path = File::Spec->catdir($self->paths->[0], split '/', $rel);
  make_path(dirname $path) unless -d dirname $path;
  my $tx = $self->ua->get($url);

  if ($tx->error) {
    diag 'Unable to download "%s": %s', $url, $tx->error->{message} if DEBUG;
    return undef;
  }

  $app->log->info(qq(Caching "$url" to "$path".));
  spurt $tx->res->body, $path;

  my $h = $tx->res->headers;
  if ($h->last_modified) {
    $attrs{mtime} = Mojo::Date->new($h->last_modified)->epoch;
  }
  if (my $ct = $h->content_type) {
    $attrs{format} = 'css' if $ct =~ /css/;
    $attrs{format} = 'js'  if $ct =~ /javascript/;
  }

  $attrs{key} = 'original';
  $attrs{url} = $url->to_string;
  $self->_db(save => \%attrs);
  return Mojo::Asset::File->new(path => $path);
}

sub _reset {

  #system sprintf "cat %s | json_xs", $_[0]->_file;
  unlink $_[0]->_file;
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::Assetpipe::Store - Storage for assets

=head1 DESCRIPTION

L<Mojolicious::Plugin::Assetpipe::Store> is an object to manage cached
assets on disk.

The idea is that a L<Mojolicious::Plugin::Assetpipe::Pipe> object can store
an asset after it is processed. This will speed up development, since only
changed assets will be processed and it will also allow processing tools to
be optional in production environment.

This module will document meta data about each asset which is saved to disk, so
it can be looked up later as a unique item using L</load>.

=head1 ATTRIBUTES

L<Mojolicious::Plugin::Assetpipe::Store> inherits all attributes from
L<Mojolicious::Static> implements the following new ones.

=head2 default_headers

  $hash_ref = $self->default_headers;
  $self = $self->default_headers({"Cache-Control" => "max-age=31536000"});

Used to set default headers used by L</serve_asset>.

=head2 ua

  $ua = $self->ua;

See L<Mojolicious::Plugin::Assetpipe/ua>.

=head1 METHODS

L<Mojolicious::Plugin::Assetpipe::Store> inherits all attributes from
L<Mojolicious::Static> implements the following new ones.

=head2 attrs

  $hash_ref = $self->attrs({key => $key, url => $url});

Will lookup L<attributes|Mojolicious::Plugin::Assetpipe::Asset/ATTRIBUTES> for
a file in the database by "url" and "key". Returns "undef" if no attributes
has been documented.

=head2 file

  $asset = $self->file($rel);

Override L<Mojolicious::Static/file> with the possibility to download assets
from web. L<Mojolicious::Static/paths> can therefor also contain URLs where
the C<$rel> file can be downloaded from.

Note that assets from web will be cached locally, which means that you need to
delete the files on disk to download a new version.

=head2 load

  $bool = $self->load($asset, \%attr);

Used to load an existing asset from disk. C<%attr> will override the
way an asset is looked up. The example below will ignore
L<minified|Mojolicious::Plugin::Assetpipe::Asset/minified> and rather use
the value from C<%attr>:

  $bool = $self->load($asset, {minified => $bool});

=head2 save

  $bool = $self->save($asset, \%attr);

Used to save an asset to disk. C<%attr> are usually the same as
L<Mojolicious::Plugin::Assetpipe::Asset/TO_JSON> and used to document metadata
about the C<$asset> so it can be looked up using L</load>.

=head2 serve_asset

Override L<Mojolicious::Static/serve_asset> with the functionality to set
response headers first, from L</default_headers>.

=head1 SEE ALSO

L<Mojolicious::Plugin::Assetpipe>.

=cut
