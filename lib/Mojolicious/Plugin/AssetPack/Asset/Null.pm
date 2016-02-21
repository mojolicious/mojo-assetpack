package Mojolicious::Plugin::AssetPack::Asset::Null;
use Mojo::Base 'Mojolicious::Plugin::AssetPack::Asset';
1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::AssetPack::Asset::Null - Skipped asset

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Asset::Null> is a subclass of
L<Mojolicious::Plugin::AssetPack::Asset> with no new functionality.

The special thing about this class is that it will be ignored when
generating output assets.

=head1 SEE ALSO

L<Mojolicious::Plugin::AssetPack>.

=cut
