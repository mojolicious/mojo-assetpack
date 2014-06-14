use t::Helper;

{
  diag "minify=0";
  my $t = t::Helper->t({ minify => 0 });

  plan skip_all => 'Could not find preprocessors for less', 6 unless $t->app->asset->preprocessors->has_subscribers('less');

  $t->app->asset('less.css' => '/css/a.less', '/css/b.less');

  $t->get_ok('/less')
    ->status_is(200)
    ->content_like(qr{<link href="/packed/a-\w+\.css".*<link href="/packed/b-\w+\.css"}s)
    ;
}

{
  diag "minify=1";
  my $t = t::Helper->t({ minify => 1 });

  $t->app->asset('less.css' => '/css/a.less', '/css/b.less');

  $t->get_ok('/less'); # trigger pack_stylesheets() twice for coverage

  $t->get_ok('/less')
    ->status_is(200)
    ->content_like(qr{<link href="/packed/less-8dd04d9b9e50ace10e29f7c5d0b2b39d\.css".*}m)
    ;

  $t->get_ok($t->tx->res->dom->at('link')->{href})
    ->status_is(200)
    ->content_like(qr{a1a1a1.*b1b1b1}s)
    ;
}

done_testing;

__DATA__
@@ less.html.ep
%= asset 'less.css'
