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
    ok $assetpack->preprocessors->has_subscribers('less'), 'found preprocessor for less';
  }
  else {
    ok !$assetpack->preprocessors->has_subscribers('less'), 'did not find preprocessor for less';
  }
}

{
  my $bin = qx{which sass};
  if($bin =~ /\w/) {
    ok $assetpack->preprocessors->has_subscribers('scss'), 'found preprocessor for scss';
  }
  else {
    ok !$assetpack->preprocessors->has_subscribers('scss'), 'did not find preprocessor for scss';
  }
}

{
  ok $assetpack->preprocessors->has_subscribers('js'), 'found preprocessor for js';
}

{
  ok $assetpack->preprocessors->has_subscribers('css'), 'found preprocessor for css';
}

done_testing;
