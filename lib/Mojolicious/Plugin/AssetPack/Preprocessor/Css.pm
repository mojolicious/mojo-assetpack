package Mojolicious::Plugin::AssetPack::Preprocessor::Css;
use Mojo::Base 'Mojolicious::Plugin::AssetPack::Preprocessor';

sub process {
  my ($self, $assetpack, $text, $path) = @_;

  if ($assetpack->minify and length $$text) {
    require CSS::Minifier::XS;
    $$text = CSS::Minifier::XS::minify($$text)
      // die "CSS::Minifier::XS::minify could not minify $path";
  }

  return $self;
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::AssetPack::Preprocessor::Css - DEPRECATED

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Preprocessor::Css> will be DEPRECATED.
Use L<Mojolicious::Plugin::AssetPack::Pipe::Css> instead.

=head1 METHODS

=head2 process

=head1 SEE ALSO

L<Mojolicious::Plugin::AssetPack>.

L<http://thorsen.pm/perl/2016/02/21/rewriting-assetpack-plugin.html>

=cut
