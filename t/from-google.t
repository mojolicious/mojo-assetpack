use warnings;
use strict;
use Test::More;
use Test::Mojo;

plan skip_all => 'TEST_ONLINE=1 required' unless $ENV{TEST_ONLINE};

unlink glob 't/public/packed/*';

my $t = Test::Mojo->new;

{
  use Mojolicious::Lite;
  plugin 'AssetPack' => { minify => 1 };
  app->asset('app.css' => 'http://fonts.googleapis.com/css?family=Lora:400,700,400italic,700italic');
  get '/css' => 'css';
}

{
  $t->get_ok('/css')->status_is(200)->content_like(qr{href="/packed/app-\w+\.css".*}m);
  $t->get_ok($t->tx->res->dom->at('link')->{href})->status_is(200);

  ok -s 't/public/packed/http___fonts_googleapis_com_css_family_Lora_400_700_400italic_700italic.css', 'cached jquery asset';
}

done_testing;

__DATA__
@@ css.html.ep
%= asset 'app.css'
