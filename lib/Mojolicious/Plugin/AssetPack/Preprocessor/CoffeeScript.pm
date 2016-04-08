package Mojolicious::Plugin::AssetPack::Preprocessor::CoffeeScript;
use Mojo::Base 'Mojolicious::Plugin::AssetPack::Preprocessor::JavaScript';
use File::Which ();

has executable => sub { File::Which::which('coffee') || 'coffee' };

sub can_process { -f $_[0]->executable ? 1 : 0 }

sub process {
  my ($self, $assetpack, $text, $path) = @_;
  my @cmd = ($self->executable, '--compile', '--stdio');

  $self->_run(\@cmd, $text, $text);

  return $self->minify($text) if $assetpack->minify;
  return $self;
}

sub _url {'http://coffeescript.org/#installation'}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::AssetPack::Preprocessor::CoffeeScript - DEPRECATED

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Preprocessor::CoffeeScript> will be DEPRECATED.
Use L<Mojolicious::Plugin::AssetPack::Pipe::CoffeeScript> instead.

=head1 ATTRIBUTES

=head2 executable

=head1 METHODS

=head2 can_process

=head2 process

=head1 SEE ALSO

L<Mojolicious::Plugin::AssetPack>.

L<http://thorsen.pm/perl/2016/02/21/rewriting-assetpack-plugin.html>

=cut
