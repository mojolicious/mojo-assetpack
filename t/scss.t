use t::Helper;

{
  diag "minify=0";
  my $t = t::Helper->t({minify => 0});

  plan skip_all => 'Could not find preprocessors for scss' unless $t->app->asset->preprocessors->can_process('scss');

  $t->app->asset('scss.css' => '/css/a.scss', '/css/b.scss');

  # test "sass -I" (--load-path)
  $t->app->asset('include-dir.css' => '/sass/y.scss');
  $t->app->routes->get('/include-dir' => 'include-dir');

  # Fix bug when asset has the same moniker as one of the source files (0.0601)
  $t->app->asset('x.css' => '/sass/x.scss');
  $t->app->routes->get('/x' => 'x');

  $t->get_ok('/test1')->status_is(200)->content_like(qr{<link href="/packed/a-\w+\.css"})
    ->content_like(qr{<link href="/packed/b-\w+\.css"});

  $t->get_ok('/x')->status_is(200)->content_like(qr{<link href="/packed/x-\w+\.css"});

  $t->get_ok($t->tx->res->dom->at('link')->{href})->status_is(200)->content_like(qr{background: \#abcdef});

  $t->get_ok('/include-dir')->content_like(qr{<link href="/packed/y-47cfc3af7162086fe15b5b8d1623f8c9\.css".*}m)
    ->status_is(200);
}

{
  diag "minify=1";
  my $t = t::Helper->t({minify => 1});

  $t->app->asset('scss.css' => '/css/a.scss', '/css/b.scss');

  $t->get_ok('/test1')->status_is(200)
    ->content_like(qr{<link href="/packed/scss-53f756a54b650d23d1ddb705c10c97d6\.css".*}m);

  $t->get_ok($t->tx->res->dom->at('link')->{href})->status_is(200)->content_like(qr{a1a1a1.*b1b1b1}s);
}

done_testing;

__DATA__
@@ test1.html.ep
%= asset 'scss.css'
@@ x.html.ep
%= asset 'x.css'
@@ include-dir.html.ep
%= asset 'include-dir.css'
