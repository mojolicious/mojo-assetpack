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
  app->asset('app.js' => 'http://code.jquery.com/jquery-1.11.0.min.js');
  get '/js' => 'js';
}

{
  $t->get_ok('/js')->status_is(200)->content_like(qr{<script src="/packed/app-\w+\.js".*}m);
  $t->get_ok($t->tx->res->dom->at('script')->{src})->status_is(200)->content_like(qr{jQuery}s);

  ok -s 't/public/packed/http___code.jquery.com_jquery-1.11.0.min.js', 'cached jquery asset';
}

done_testing;

__DATA__
@@ js.html.ep
%= asset 'app.js'
