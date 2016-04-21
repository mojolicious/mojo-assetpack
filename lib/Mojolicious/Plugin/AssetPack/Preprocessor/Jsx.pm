package Mojolicious::Plugin::AssetPack::Preprocessor::Jsx;
use Mojo::Base 'Mojolicious::Plugin::AssetPack::Preprocessor::JavaScript';
use File::Which ();

has executable => sub { File::Which::which('jsx') || 'jsx' };

sub can_process { -f $_[0]->executable ? 1 : 0 }

sub process {
  my ($self, $assetpack, $text, $path) = @_;
  my $out;

  unless (eval { $self->_run([$self->executable], $text, $text) }) {
    $@ =~ s!\s*at throwError.*!!s unless $ENV{MOJO_ASSETPACK_DEBUG};
    $@ =~ s!\x1B\[\d{1,2}m!!g;    # remove color codes
    die $@;
  }

  return $self->minify($text) if $assetpack->minify;
  return $self;
}

sub _url {'http://facebook.github.io/react'}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::AssetPack::Preprocessor::Jsx - DEPRECATED

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Preprocessor::Jsx> will be DEPRECATED.
No replacement is planned.

=head1 ATTRIBUTES

=head2 executable

=head1 METHODS

=head2 can_process

=head2 process

=head1 SEE ALSO

L<Mojolicious::Plugin::AssetPack>.

L<http://thorsen.pm/perl/2016/02/21/rewriting-assetpack-plugin.html>

=cut
