package Mojolicious::Plugin::Assetpipe::Store;
use Mojo::Base 'Mojolicious::Static';
use Mojo::JSON;
use Mojo::Util qw(slurp spurt);
use Mojo::URL;
use Mojolicious::Plugin::Assetpipe::Util qw(diag checksum has_ro DEBUG);
use File::Basename 'dirname';
use File::Path 'make_path';

# MOJO_ASSETPIPE_DB_FILE is used in tests
use constant DB_FILE => $ENV{MOJO_ASSETPIPE_DB_FILE} || 'assetpipe.db';

has_ro 'ua';

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
  my ($self, $attr) = @_;
  my @rel = $self->_cache_path($attr);
  my $file = $self->file(join '/', @rel);

  return 0 unless $file;
  return 0 unless $self->_db($attr)->{checksum} eq $attr->{checksum};
  diag 'Load "%s" = 1', eval { $file->path } || join('/', @rel) if DEBUG;
  return $file;
}

sub save {
  my ($self, $ref, $attr) = @_;
  my $path = File::Spec->catfile($self->paths->[0], $self->_cache_path($attr));
  my $dir = dirname $path;

  # Do not care if this fail. Can fallback to temp files.
  mkdir $dir if !-d $dir and -w dirname $dir;
  diag 'Save "%s" = %s', $path, -d $dir ? 1 : 0 if DEBUG;

  return Mojo::Asset::Memory->new->add_chunk($$ref) unless -w $dir;
  $self->_db($attr, 1);
  spurt $$ref, $path;
  return Mojo::Asset::File->new(path => $path);
}

sub _cache_path {
  my ($self, $attr) = @_;
  return (
    'cache', sprintf '%s-%s.%s%s',
    $attr->{name},
    checksum($attr->{url}),
    $attr->{minified} ? 'min.' : '',
    $attr->{format}
  );
}

sub _db {
  my ($self, $attr, $save) = @_;
  my $db_file = File::Spec->catfile($self->paths->[0], DB_FILE);

  my $db = $self->{_db} ||= do {
    -r $db_file ? Mojo::JSON::decode_json(slurp $db_file) : {};
  };

  my $data = $db->{$attr->{url}} ||= {};
  my $key = sprintf 'minified:%s', $attr->{minified} ? 1 : 0;
  $data = $data->{$key} ||= {checksum => '', format => '', mtime => 0};

  if ($save) {
    $data->{$_} = $attr->{$_} for qw(checksum format mtime);
    diag 'Save "%s" = %s', $db_file, -w $self->paths->[0] ? 1 : 0 if DEBUG;
    spurt Mojo::JSON::encode_json($db), $db_file if -w $self->paths->[0];
  }

  return $data;
}

sub _download {
  my ($self, $url) = @_;
  my $rel = $url->clone->to_abs;

  $rel->port(undef)->scheme(undef);
  $rel = $rel->to_string;
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
    my $mtime = Mojo::Date->new($h->last_modified)->epoch;
    utime $mtime, $mtime, $path;
  }

  return Mojo::Asset::File->new(path => $path);
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

=head2 ua

  $ua = $self->ua;

See L<Mojolicious::Plugin::Assetpipe/ua>.

=head1 METHODS

L<Mojolicious::Plugin::Assetpipe::Store> inherits all attributes from
L<Mojolicious::Static> implements the following new ones.

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

=head1 SEE ALSO

L<Mojolicious::Plugin::Assetpipe>.

=cut
