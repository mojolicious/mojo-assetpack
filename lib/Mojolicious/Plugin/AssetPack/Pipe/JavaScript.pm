package Mojolicious::Plugin::AssetPack::Pipe::JavaScript;
use Mojo::Base 'Mojolicious::Plugin::AssetPack::Pipe';

use Mojolicious::Plugin::AssetPack::Util qw(diag load_module DEBUG);

sub process {
  my ($self, $assets) = @_;

  return unless $self->assetpack->minify;
  return $assets->each(sub {
    my ($asset, $index) = @_;
    my $attrs = $asset->TO_JSON(minified => 1, key => 'min');
    return if $asset->format ne 'js' or $asset->minified;
    return if $self->store->load($asset, $attrs);
    return if !length(my $js = $asset->content);
    load_module 'JavaScript::Minifier::XS';
    diag 'Minify "%s" with checksum %s.', $asset->url, $asset->checksum if DEBUG;
    $js = JavaScript::Minifier::XS::minify($js);
    $self->store->save($asset, \$js, $attrs);
  });
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::AssetPack::Pipe::JavaScript - Minify JavaScript

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Pipe::JavaScript> will minify your "js"
assets if L<Mojolicious::Plugin::AssetPack/minify> is true and the asset is
not already minified.

=head1 METHODS

=head2 process

See L<Mojolicious::Plugin::AssetPack::Pipe/process>.

=head1 SEE ALSO

L<Mojolicious::Plugin::AssetPack>.

=cut
