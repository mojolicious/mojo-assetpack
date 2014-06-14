use t::Helper;

{
  diag "minify=0";
  my $t = t::Helper->t({ minify => 0 });

  ok $t->app->asset->preprocessors->has_subscribers('js'), 'found preprocessor for js';

  $t->app->asset('app.js' => '/js/a.js', '/js/b.js');

  is_deeply(
    [ $t->app->asset->get('app.js') ],
    [ '/js/a.js', '/js/b.js' ],
    'get(app.js)'
  );

  $t->get_ok('/js')
    ->status_is(200)
    ->content_like(qr{<script src="/js/a\.js".*<script src="/js/b\.js"}s)
    ;
}

{
  diag "minify=1";
  my $t = t::Helper->t({ minify => 1 });

  $t->app->asset('app.js' => '/js/a.js', '/js/b.js');

  $t->get_ok('/js'); # trigger pack_javascripts() twice for coverage
  $t->get_ok('/js')
    ->status_is(200)
    ->content_like(qr{<script src="/packed/app-8072d187db8ff7a1809b88ae1a5f3bd7\.js".*}m)
    ;

  $t->get_ok($t->tx->res->dom->at('script')->{src})
    ->status_is(200)
    ->content_like(qr{["']a["'].*["']b["']}s)
    ;

  is_deeply(
    [ $t->app->asset->get('app.js') ],
    [ '/packed/app-8072d187db8ff7a1809b88ae1a5f3bd7.js' ],
    'get(app.js)'
  );
}

done_testing;

__DATA__
@@ js.html.ep
%= asset 'app.js'
