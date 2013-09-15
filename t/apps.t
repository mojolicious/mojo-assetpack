use warnings;
use strict;
use Test::More;
use Test::Mojo;

plan skip_all => 'Not ready for alien host' unless $^O eq 'linux';

my $assetpack;

{
  use Mojolicious::Lite;
  plugin 'AssetPack';
  $assetpack = app->asset;

  isa_ok $assetpack, 'Mojolicious::Plugin::AssetPack';
}

{
  my $bin = qx{which lessc};
  if($bin =~ /\w/) {
    ok $assetpack->{preprocessor}{less}, 'found preprocessor for less';
  }
  else {
    ok !$assetpack->{preprocessor}{less}, 'did not find preprocessor for less';
  }
}

{
  my $bin = qx{which sass};
  if($bin =~ /\w/) {
    ok $assetpack->{preprocessor}{scss}, 'found preprocessor for scss';
  }
  else {
    ok !$assetpack->{preprocessor}{scss}, 'did not find preprocessor for scss';
  }
}

{
  my $bin = qx{which yuicompressor};
  if($bin =~ /\w/) {
    ok $assetpack->{preprocessor}{js}, 'found preprocessor for js';
    ok $assetpack->{preprocessor}{css}, 'found preprocessor for css';
  }
  else {
    ok !$assetpack->{preprocessor}{js}, 'did not find preprocessor for js';
    ok !$assetpack->{preprocessor}{css}, 'did not find preprocessor for css';
  }
}


done_testing;
