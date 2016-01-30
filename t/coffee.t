use t::Helper;
my $t = t::Helper->t;
plan skip_all => 'TEST_COFFEE=1' unless $ENV{TEST_COFFEE} or -e '.test-everything';

$t->app->asset->process('app.js' => 'foo.coffee');
$t->get_ok('/')->status_is(200)
  ->element_exists(qq(script[src="/asset/e4c4b04389/foo.js"]));

$t->get_ok($t->tx->res->dom->at('script')->{src})->status_is(200)
  ->content_like(qr{console.log\('hello from foo coffee'\)});

done_testing;

__DATA__
@@ index.html.ep
%= asset 'app.js'
@@ foo.coffee
console.log 'hello from foo coffee'
