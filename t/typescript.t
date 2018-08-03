use lib '.';
use t::Helper;
plan skip_all => 'TEST_TYPESCRIPT=1' unless $ENV{TEST_TYPESCRIPT} or -e '.test-everything';

my $t = t::Helper->t(pipes => ['TypeScript']);
$t->app->asset->process('app.js' => 'foo.ts');
$t->get_ok('/')->status_is(200)->element_exists(qq(script[src="/asset/8e77d0ac51/foo.js"]));

$t->get_ok($t->tx->res->dom->at('script')->{src})->status_is(200)->content_like(qr{var n = 1;});

done_testing;

__DATA__
@@ index.html.ep
%= asset 'app.js'
@@ foo.ts
var n: number = 1;
