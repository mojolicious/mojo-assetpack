use t::Helper;

{
  my $t = t::Helper->t({minify => 0});

  plan skip_all => 'Could not find preprocessors for sass' unless $t->app->asset->preprocessors->can_process('sass');

  $t->app->asset('sass.css' => '/sass/a.sass');
  $t->get_ok('/test1')->status_is(200)->content_like(qr{<link href="/packed/a-\w+\.css"});
  $t->get_ok($t->tx->res->dom->at('link')->{href})->status_is(200)->content_like(qr{sans-serif;\s});
}

{
  my $t = t::Helper->t({minify => 1});

  $t->app->asset('sass.css' => '/sass/a.sass');
  $t->get_ok('/test1')->status_is(200)
    ->content_like(qr{<link href="/packed/sass-0c60d31af2de1ab7ea0108b8e866f87d\.min\.css"});
  $t->get_ok($t->tx->res->dom->at('link')->{href})->status_is(200)
    ->content_like(qr{font:100% Helvetica,sans-serif;color:\#333});
}

is(Mojolicious::Plugin::AssetPack::Preprocessor::Sass->_url, 'http://sass-lang.com/install', '_url');

done_testing;

__DATA__
@@ test1.html.ep
%= asset 'sass.css'
@@ x.html.ep
%= asset 'x.css'
@@ include-dir.html.ep
%= asset 'include-dir.css'
