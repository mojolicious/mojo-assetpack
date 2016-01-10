package Mojolicious::Plugin::Assetpipe::Pipe::Combine;
use Mojo::Base 'Mojolicious::Plugin::Assetpipe::Pipe';
use Mojolicious::Plugin::Assetpipe::Util qw(checksum diag DEBUG);

sub _combine {
  my ($self, $assets) = @_;

  return unless $self->assetpipe->minify;
  my $checksum = checksum $assets->map('checksum')->join(':');
  diag 'Combining assets into "%s" with checksum %s.', $self->topic, $checksum if DEBUG;
  @$assets = ($assets->first->new(assetpipe => $self->assetpipe, url => $self->topic)
      ->checksum($checksum)->minified(1)->content($assets->map('content')->join("\n")));
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::Assetpipe::Pipe::Combine - Combine multiple assets to one

=head1 DESCRIPTION

L<Mojolicious::Plugin::Assetpipe::Pipe::Combine> will take a list of
assets and turn them into a single asset.

=head1 SEE ALSO

L<Mojolicious::Plugin::Assetpipe>.

=cut
