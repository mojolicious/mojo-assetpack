package Mojolicious::Plugin::AssetPack::Preprocessor::Sass;
use Mojo::Base 'Mojolicious::Plugin::AssetPack::Preprocessor::Scss';
use File::Basename 'dirname';
use constant LIBSASS_BINDINGS => defined $ENV{ENABLE_LIBSASS_BINDINGS}
  ? $ENV{ENABLE_LIBSASS_BINDINGS}
  : eval 'require CSS::Sass;1';

sub _extension {'sass'}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::AssetPack::Preprocessor::Sass - DEPRECATED

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Preprocessor::Sass> will be DEPRECATED.
Use L<Mojolicious::Plugin::AssetPack::Pipe::Sass> instead.

=head1 SEE ALSO

L<Mojolicious::Plugin::AssetPack>.

L<http://thorsen.pm/perl/2016/02/21/rewriting-assetpack-plugin.html>

=cut
