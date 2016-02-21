package Mojolicious::Plugin::AssetPack::Pipe::Combine;
use Mojo::Base 'Mojolicious::Plugin::AssetPack::Pipe';
use Mojolicious::Plugin::AssetPack::Util qw(checksum diag DEBUG);

sub process {
  my ($self, $assets) = @_;

  return unless $self->assetpack->minify;
  my $checksum = checksum $assets->map('checksum')->join(':');
  my $content
    = $assets->grep(sub { !$_->isa('Mojolicious::Plugin::AssetPack::Asset::Null') })
    ->map('content')->join("\n");
  diag 'Combining assets into "%s" with checksum %s.', $self->topic, $checksum if DEBUG;
  @$assets = (
    Mojolicious::Plugin::AssetPack::Asset->new(
      assetpack => $self->assetpack,
      url       => $self->topic
    )->checksum($checksum)->minified(1)->content($content)
  );
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::AssetPack::Pipe::Combine - Combine multiple assets to one

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Pipe::Combine> will take a list of
assets and turn them into a single asset.

=head1 METHODS

=head2 process

See L<Mojolicious::Plugin::AssetPack::Pipe/process>.

=head1 SEE ALSO

L<Mojolicious::Plugin::AssetPack>.

=cut
