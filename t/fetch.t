use Mojo::Base -strict;
use Test::Mojo;
use Test::More;

use Mojolicious::Lite;
plugin 'AssetPack';
get '/fetch-example.css' => { text => 'body{background:#fff}' };

my $t = Test::Mojo->new;
like $t->app->asset->fetch('/fetch-example.css'), qr{\b_fetch-example_css\.css$}, 'fetched from local app';

done_testing;
