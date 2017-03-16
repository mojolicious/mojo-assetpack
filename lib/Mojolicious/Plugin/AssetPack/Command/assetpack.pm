package Mojolicious::Plugin::AssetPack::Command::assetpack;

use Mojo::Base 'Mojolicious::Command';
use Carp;

has description => 'Process AssetPack assets for production';
has usage       => <<"EOU";
Usage: $0 assetpack

Options:
    none
EOU

sub run {
  my ($self, @args) = @_;

  my $asset = $self->app->asset;

  $asset->minify(1);

  for my $topic (keys %{$asset->{by_topic}}) {
    my $assets = $asset->{by_topic}{$topic};
    $asset->process($topic, @$assets);
  }

  return 1;
}

1;
