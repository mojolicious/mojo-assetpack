package Mojolicious::Plugin::Assetpipe::Pipe::Css;
use Mojo::Base 'Mojolicious::Plugin::Assetpipe::Pipe';
use Mojolicious::Plugin::Assetpipe::Util qw(diag load_module DEBUG);

sub _process {
  my ($self, $assets) = @_;

  return unless $self->assetpipe->minify;
  return $assets->each(
    sub {
      my ($asset, $index) = @_;
      return
           if $asset->format ne 'css'
        or $asset->minified
        or $asset->cache_load({minified => 1});
      load_module 'CSS::Minifier::XS' or die qq(Could not load "CSS::Minifier::XS": $@);
      diag 'Minify "%s" with checksum "%s".', $asset->url, $asset->checksum if DEBUG;
      $asset->minified(1)->content(CSS::Minifier::XS::minify($asset->content));
    }
  );
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::Assetpipe::Pipe::Css - Minify CSS

=head1 DESCRIPTION

L<Mojolicious::Plugin::Assetpipe::Pipe::Css> will minify your "css" assets
if L<Mojolicious::Plugin::Assetpipe/minify> is true and the asset is not
already minified.

This module require the optional module L<CSS::Minifier::XS> to minify.

=head1 SEE ALSO

L<Mojolicious::Plugin::Assetpipe>.

=cut
