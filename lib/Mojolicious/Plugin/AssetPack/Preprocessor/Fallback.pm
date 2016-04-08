package Mojolicious::Plugin::AssetPack::Preprocessor::Fallback;
use Mojo::Base 'Mojolicious::Plugin::AssetPack::Preprocessor';

sub can_process {0}

sub process {
  my ($self, $assetpack, $text, $path) = @_;
  die "No preprocessor defined for $path\n";
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::AssetPack::Preprocessor::Fallback - DEPRECATED

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Preprocessor::Fallback> will be DEPRECATED.

=head1 METHODS

=head2 can_process

=head2 process

=head1 SEE ALSO

L<Mojolicious::Plugin::AssetPack>.

L<http://thorsen.pm/perl/2016/02/21/rewriting-assetpack-plugin.html>

=cut
