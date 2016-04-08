use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use Mojolicious::Lite;

plan skip_all => 'TEST_OLD=1' unless $ENV{TEST_OLD};

plugin 'AssetPack';

my $t         = Test::Mojo->new;
my $assetpack = $t->app->asset;

plugin 'AssetPack';
is $t->app->asset, $assetpack, 'same assetpack';

done_testing;
