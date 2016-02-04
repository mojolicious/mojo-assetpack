use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use Mojolicious::Lite;

plugin 'AssetPack';

my $t         = Test::Mojo->new;
my $assetpack = $t->app->asset;

plugin 'AssetPack';
is $t->app->asset, $assetpack, 'same assetpack';

done_testing;
