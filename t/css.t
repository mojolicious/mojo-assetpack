use t::Helper;

{
  diag "minify=0";
  my $t = t::Helper->t({minify => 0});

  ok $t->app->asset->preprocessors->can_process('css'), 'found preprocessor for css';

  $t->app->asset('app.css' => '/css/a.css', '/css/b.css');

  $t->get_ok('/test1')->status_is(200)
    ->content_like(
    qr{<link href="/packed/a-09a653553edca03ad3308a868e5a06ac\.css".*<link href="/packed/b-89dbc5a64c4e7e64a3d1ce177b740a7e\.css"}s
    );

  $t->get_ok('/packed/a-09a653553edca03ad3308a868e5a06ac.css')->content_like(qr{a1a1a1;});
  $t->get_ok('/packed/b-89dbc5a64c4e7e64a3d1ce177b740a7e.css')->content_like(qr{b1b1b1;});
}

{
  diag "minify=1";
  my $t = t::Helper->t({minify => 1});

  $t->app->asset('app.css' => '/css/c.css', '/css/d.css');

  $t->get_ok('/test1')->status_is(200)
    ->content_like(qr{<link href="/packed/app-3659f2c6b80de93f8373568a1ddeffaa\.css".*}m);

  $t->get_ok($t->tx->res->dom->at('link')->{href})->status_is(200)->content_like(qr{c1c1c1.*d1d1d1});
}

done_testing;

__DATA__
@@ test1.html.ep
%= asset 'app.css'
