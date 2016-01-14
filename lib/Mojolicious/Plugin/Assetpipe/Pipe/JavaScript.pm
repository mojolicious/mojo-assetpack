package Mojolicious::Plugin::Assetpipe::Pipe::JavaScript;
use Mojo::Base 'Mojolicious::Plugin::Assetpipe::Pipe';
use Mojolicious::Plugin::Assetpipe::Util qw(diag load_module DEBUG);

sub _process {
  my ($self, $assets) = @_;
  my $store = $self->assetpipe->store;
  my $file;

  return unless $self->assetpipe->minify;
  return $assets->each(
    sub {
      my ($asset, $index) = @_;
      my $attr = $asset->TO_JSON;
      $attr->{minified} = 1;
      return if $asset->format ne 'js' or $asset->minified;
      return $asset->content($file)->minified(1) if $file = $store->load($attr);
      return unless length(my $js = $asset->content);
      load_module 'JavaScript::Minifier::XS'
        or die qq(Could not load "JavaScript::Minifier::XS": $@);
      diag 'Minify "%s" with checksum %s.', $asset->url, $asset->checksum if DEBUG;
      $js = JavaScript::Minifier::XS::minify($js);
      $asset->content($store->save(\$js, $attr))->minified(1);
    }
  );
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::Assetpipe::Pipe::JavaScript - Minify JavaScript

=head1 DESCRIPTION

L<Mojolicious::Plugin::Assetpipe::Pipe::JavaScript> will minify your "js"
assets if L<Mojolicious::Plugin::Assetpipe/minify> is true and the asset is
not already minified.

=head1 SEE ALSO

L<Mojolicious::Plugin::Assetpipe>.

=cut
