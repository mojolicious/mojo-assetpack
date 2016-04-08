package Mojolicious::Plugin::AssetPack::Preprocessor::Less;
use Mojo::Base 'Mojolicious::Plugin::AssetPack::Preprocessor';
use File::Which ();

has executable => sub { File::Which::which('lessc') || 'lessc' };

sub can_process { -f $_[0]->executable ? 1 : 0 }

sub process {
  my ($self, $assetpack, $text, $path) = @_;
  my @cmd = ($self->executable);

  push @cmd, '-';                          # read from stdin
  push @cmd, '-x' if $assetpack->minify;

  return $self->_run(\@cmd, $text, $text);
}

sub _url {'http://lesscss.org/#usage'}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::AssetPack::Preprocessor::Less - DEPRECATED

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Preprocessor::Less> will be DEPRECATED.
Use L<Mojolicious::Plugin::AssetPack::Pipe::Less> instead.

=head1 ATTRIBUTES

=head2 executable

=head1 METHODS

=head2 can_process

=head2 process

=head1 SEE ALSO

L<Mojolicious::Plugin::AssetPack>.

=cut
