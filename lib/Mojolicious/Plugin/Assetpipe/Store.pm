package Mojolicious::Plugin::Assetpipe::Store;
use Mojo::Base 'Mojolicious::Static';
use Mojo::JSON;
use Mojo::Util qw(slurp spurt);
use Mojolicious::Plugin::Assetpipe::Util qw(diag checksum DEBUG);
use File::Basename 'dirname';

# MOJO_ASSETPIPE_DB_FILE is used in tests
use constant DB_FILE => $ENV{MOJO_ASSETPIPE_DB_FILE} || 'assetpipe.db';

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
