use t::Helper;

plan skip_all => 'TEST_ONLINE=1 required' unless $ENV{TEST_ONLINE};

{
  my $t = t::Helper->t({minify => 1});

  $t->app->asset('app.css' => 'http://fonts.googleapis.com/css?family=Lora:400,700,400italic,700italic');

  $t->get_ok('/google-font')->status_is(200)->content_like(qr{href="/packed/app-\w+\.css"}m);
  $t->get_ok($t->tx->res->dom->at('link')->{href})->status_is(200)->content_like(qr{\@font-face.*http://font}s);

  ok -s 't/public/packed/http___fonts_googleapis_com_css_family_Lora_400_700_400italic_700italic.css', 'cached font';
}

{
  my $t = t::Helper->t({minify => 0});

  $t->app->asset('app.css' => 'http://fonts.googleapis.com/css?family=Lora:400,700,400italic,700italic');
  $t->get_ok('/google-font')->status_is(200)
    ->content_like(
    qr{href="/packed/http___fonts_googleapis_com_css_family_Lora_400_700_400italic_700italic-4400fcdefbb94925100757aca904c3af\.css"}m
    );
  $t->get_ok($t->tx->res->dom->at('link')->{href})->status_is(200);
}

done_testing;

__DATA__
@@ google-font.html.ep
%= asset 'app.css'
