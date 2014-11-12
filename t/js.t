use t::Helper;

{
  diag "minify=0";
  my $t = t::Helper->t({minify => 0});

  ok $t->app->asset->preprocessors->can_process('js'), 'found preprocessor for js';

  $t->app->asset('app.js' => '/js/a.js', '/js/b.js');

  is_deeply(
    [$t->app->asset->get('app.js')],
    ['/packed/a-527b09c38362b669ec6e16c00d9fb30d.js', '/packed/b-99eec25eb4441cda45d464c03b92a536.js'],
    'get(app.js)'
  );

  $t->get_ok('/test1')->status_is(200)
    ->content_like(
    qr{<script src="/packed/a-527b09c38362b669ec6e16c00d9fb30d\.js".*<script src="/packed/b-99eec25eb4441cda45d464c03b92a536\.js"}s
    );
}

{
  diag "minify=1";
  my $t = t::Helper->t({minify => 1});
  my $b_func = quotemeta
    '(function(){var module={exports:{}};var i=200;var foo=(function(){var module={exports:{}};module.exports.fn=function(n){return"foo:"+n};return module.exports;})();module.exports=function(n){return foo.fn(n*i)};return module.exports;})()';

  $t->app->asset('app.js' => '/js/a.js', '/js/b.js');

  $t->get_ok('/test1');    # trigger pack_javascripts() twice for coverage
  $t->get_ok('/test1')->status_is(200)
    ->content_like(qr{<script src="/packed/app-ec1f584de6b736ca6aea95c003e498aa\.js".*}m);

  $t->get_ok($t->tx->res->dom->at('script')->{src})->status_is(200)->content_like(qr{["']a["'].*["']b["']}s);

  is_deeply([$t->app->asset->get('app.js')], ['/packed/app-ec1f584de6b736ca6aea95c003e498aa.js'], 'get(app.js)');

  $t->app->asset('require.js' => '/js/require.js');
  $t->get_ok('/test1')->content_like(qr{var a=1;var b=$b_func;b=$b_func;}, 'b_func');
}

done_testing;

__DATA__
@@ test1.html.ep
%= asset 'app.js'
%= asset 'require.js', { inline => 1 }
