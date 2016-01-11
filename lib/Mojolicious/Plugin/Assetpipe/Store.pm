package Mojolicious::Plugin::Assetpipe::Store;
use Mojo::Base 'Mojolicious::Static';
use Mojo::Util 'spurt';
use Mojolicious::Plugin::Assetpipe::Util qw(diag checksum DEBUG);
use File::Basename 'dirname';

# TODO: Remove access to private attribute $asset->_asset()

sub load {
  my ($self, $asset, $args) = @_;
  my @rel = $self->_cache_path($asset, $args || {});
  my $file = $self->file(join '/', @rel);

  diag 'Load "%s": %s', eval { $file->path } || join('/', @rel), $file ? 1 : 0 if DEBUG;
  return 0 unless $file;
  $asset->$_($args->{$_}) for keys %$args;
  $asset->_asset($file);
}

sub save {
  my ($self, $asset) = @_;
  my $path = File::Spec->catfile($self->paths->[0], $self->_cache_path($asset, {}));
  my $dir = dirname $path;

  # Do not care if this fail. Can fallback to temp files.
  mkdir $dir if !-d $dir and -w dirname $dir;
  diag 'Save "%s": %s', $path, -d $dir ? 1 : 0 if DEBUG;
  return 0 unless -w $dir;
  spurt $asset->content, $path;
  return $asset->_asset(Mojo::Asset::File->new(path => $path));
}

sub _cache_path {
  my ($self, $asset, $args) = @_;
  return (
    'processed', sprintf '%s-%s.%s%s',
    $asset->name,
    checksum($asset->url),
    $args->{minified} || $asset->minified ? 'min.' : '',
    $asset->format
  );
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::Assetpipe::Store - Storage for assets

=head1 DESCRIPTION

L<Mojolicious::Plugin::Assetpipe::Store> is an object to manage cached
assets on disk.

=head1 ATTRIBUTES

L<Mojolicious::Plugin::Assetpipe::Store> inherits all attributes from
L<Mojolicious::Static> implements the following new ones.

=head1 METHODS

L<Mojolicious::Plugin::Assetpipe::Store> inherits all attributes from
L<Mojolicious::Static> implements the following new ones.

=head2 load

  $bool = $self->load($asset);

=head2 save

  $bool = $self->save($asset);

=head1 SEE ALSO

L<Mojolicious::Plugin::Assetpipe>.

=cut
