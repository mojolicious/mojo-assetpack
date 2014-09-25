use t::Helper;

{
  diag "minify=0";
  my $t = t::Helper->t({ minify => 0 });

  plan skip_all => 'Could not find preprocessors for jsx', 6 unless $t->app->asset->preprocessors->has_subscribers('jsx');

  $t->app->asset('jsx.js' => '/js/c.jsx');

  $t->get_ok('/jsx')
    ->status_is(200)
    ->content_like(qr{<script src="/packed/c-\w+\.js"});

  $t->get_ok($t->tx->res->dom->at('script')->{src})
    ->status_is(200)
    ->content_like(qr{;[\n\s]+React})
    ->content_like(qr{var app\s*=\s*React\.DOM\.div\(\s*{.*"appClass"},\s*"Hello, React!"\)});
}

{
  diag "minify=1";
  my $t = t::Helper->t({ minify => 1 });

  $t->app->asset('jsx.js' => '/js/c.jsx');

  $t->get_ok('/jsx')
    ->status_is(200)
    ->content_like(qr{<script src="/packed/jsx-f222ca932c5593c33e0b71688fb96a1c\.js".*}m)
    ;

  $t->get_ok($t->tx->res->dom->at('script')->{src})
    ->status_is(200)
    ->content_like(qr{;React});
    ;
}

done_testing;

__DATA__
@@ jsx.html.ep
%= asset 'jsx.js'
