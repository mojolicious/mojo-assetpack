use t::Helper;

plan skip_all => 'TEST_ONLINE=1 required' unless $ENV{TEST_ONLINE};

{
  my $t = t::Helper->t({minify => 1});
  $t->app->asset('app.js' => 'http://code.jquery.com/jquery-1.11.0.min.js');

  $t->get_ok('/test1')->status_is(200)->content_like(qr{<script src="/packed/app-\w+\.min\.js"}m);
  $t->get_ok($t->tx->res->dom->at('script')->{src})->status_is(200)->content_like(qr{jQuery}s);

  ok -s 't/public/packed/http___code_jquery_com_jquery-1_11_0_min_js.js', 'cached jquery asset';
}

done_testing;

__DATA__
@@ test1.html.ep
%= asset 'app.js'
