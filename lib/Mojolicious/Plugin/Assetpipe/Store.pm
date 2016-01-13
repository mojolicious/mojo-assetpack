package Mojolicious::Plugin::Assetpipe::Store;
use Mojo::Base 'Mojolicious::Static';
use Mojo::JSON;
use Mojo::Util qw(slurp spurt);
use Mojolicious::Plugin::Assetpipe::Util qw(diag checksum DEBUG);
use File::Basename 'dirname';

# MOJO_ASSETPIPE_DB_FILE is used in tests
use constant DB_FILE => $ENV{MOJO_ASSETPIPE_DB_FILE} || 'assetpipe.db';

# TODO: Remove access to private attribute $asset->_asset()

sub load {
  my ($self, $asset, $attr) = @_;
  my @rel = $self->_cache_path($asset, $attr || {});
  my $file = $self->file(join '/', @rel);

  return 0 unless $file;
  return 0
    unless $self->_db($asset, $attr)->{checksum} eq
    ($attr->{checksum} || $asset->checksum);
  diag 'Load "%s" = 1', eval { $file->path } || join('/', @rel) if DEBUG;
  $asset->$_($attr->{$_}) for keys %$attr;
  $asset->_asset($file);
}

sub save {
  my ($self, $asset, $attr) = @_;
  my $path = File::Spec->catfile($self->paths->[0], $self->_cache_path($asset, $attr));
  my $dir = dirname $path;

  # Do not care if this fail. Can fallback to temp files.
  mkdir $dir if !-d $dir and -w dirname $dir;
  diag 'Save "%s" = %s', $path, -d $dir ? 1 : 0 if DEBUG;
  return 0 unless -w $dir;
  $asset->$_($attr->{$_}) for keys %$attr;
  $self->_db($asset, {}, 1);
  spurt $asset->content, $path;
  return $asset->_asset(Mojo::Asset::File->new(path => $path));
}

sub _cache_path {
  my ($self, $asset, $attr) = @_;
  return (
    'processed', sprintf '%s-%s.%s%s',
    $asset->name,
    checksum($asset->url),
    $attr->{minified} || $asset->minified ? 'min.' : '',
    $attr->{format} || $asset->format
  );
}

sub _db {
  my ($self, $asset, $attr, $save) = @_;
  my $db_file = File::Spec->catfile($self->paths->[0], DB_FILE);

  my $db = $self->{_db} ||= do {
    -r $db_file ? Mojo::JSON::decode_json(slurp $db_file) : {};
  };

  my $data = $db->{$asset->url} ||= {};
  my $key = sprintf 'minified:%s', $attr->{minified} // $asset->minified ? 1 : 0;
  $data = $data->{$key} ||= {checksum => '', format => '', mtime => 0};

  if ($save) {
    $data->{$_} = $asset->$_ for qw(checksum format mtime);
    diag 'Save "%s" = %s', $db_file, -w $self->paths->[0] ? 1 : 0 if DEBUG;
    spurt Mojo::JSON::encode_json($db), $db_file if -w $self->paths->[0];
  }

  return $data;
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

=head1 ATTRIBUTES

L<Mojolicious::Plugin::Assetpipe::Store> inherits all attributes from
L<Mojolicious::Static> implements the following new ones.

=head1 METHODS

L<Mojolicious::Plugin::Assetpipe::Store> inherits all attributes from
L<Mojolicious::Static> implements the following new ones.

=head2 load

  $bool = $self->load($asset, \%attr);

Used to load an existing asset from disk. C<%attr> will override the
way an asset is looked up. The example below will ignore
L<minified|Mojolicious::Plugin::Assetpipe::Asset/minified> and rather use
the value from C<%attr>:

  $bool = $self->load($asset, {minified => $bool});

C<%attr> will also be applied to C<$asset> if found.

=head2 save

  $bool = $self->save($asset, \%attr);

Used to save an asset to disk. C<%attr> will be applied to C<$asset>.

=head1 SEE ALSO

L<Mojolicious::Plugin::Assetpipe>.

=cut
