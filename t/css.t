use t::Helper;

{
  diag "minify=0";
  my $t = t::Helper->t({ minify => 0 });

  ok $t->app->asset->preprocessors->has_subscribers('css'), 'found preprocessor for css';

  $t->app->asset('app.css' => '/css/a.css', '/css/b.css');

  $t->get_ok('/css')
    ->status_is(200)
    ->content_like(qr{<link href="/css/a\.css".*<link href="/css/b\.css"}s)
    ;

  $t->get_ok('/css/a.css')->content_like(qr{a1a1a1;});
  $t->get_ok('/css/b.css')->content_like(qr{b1b1b1;});
}

{
  diag "minify=1";
  my $t = t::Helper->t({ minify => 1 });

  $t->app->asset('app.css' => '/css/c.css', '/css/d.css');

  $t->get_ok('/css')
    ->status_is(200)
    ->content_like(qr{<link href="/packed/app-3659f2c6b80de93f8373568a1ddeffaa\.css".*}m)
    ;

  $t->get_ok($t->tx->res->dom->at('link')->{href})
    ->status_is(200)
    ->content_like(qr{c1c1c1.*d1d1d1})
    ;
}

done_testing;

__DATA__
@@ css.html.ep
%= asset 'app.css'
