use lib '.';
use t::Helper;
plan skip_all => 'TEST_ROLLUP=1' unless $ENV{TEST_ROLLUP} or -e '.test-everything';

# Development mode
my $t = t::Helper->t(pipes => [qw(RollupJs Combine)]);
$t->app->asset->process('app.js' => 'js/some-lib.js');
$t->get_ok('/')->status_is(200)->element_exists(qq(script[src="/asset/693887ef13/some-lib.js"]));
$t->get_ok($t->tx->res->dom->at('script')->{src})->status_is(200)->content_like(qr{someLib\W+=\W+function});

# Production mode
$ENV{MOJO_MODE} = 'Test_minify_from_here';
$t = t::Helper->t(pipes => [qw(RollupJs Combine)]);
$t->app->asset->process('app.js' => 'js/some-lib.js');
$t->get_ok('/')->status_is(200)->element_exists(qq(script[src="/asset/96b3f18ab2/app.js"]));
$t->get_ok($t->tx->res->dom->at('script')->{src})->status_is(200)->content_like(qr{someLib=\W*function});

# With modules and plugins
$t = t::Helper->t(pipes => [qw(RollupJs Combine)]);
$t->app->asset->pipe('RollupJs')->add_global(vue => 'Vue');
push @{$t->app->asset->pipe('RollupJs')->modules}, 'vue-template-compiler';
push @{$t->app->asset->pipe('RollupJs')->plugins}, ['rollup-plugin-vue', 'vue'];
$t->app->asset->process('app.js' => 'js/vue-app.js');
$t->get_ok('/')->status_is(200);
$t->get_ok($t->tx->res->dom->at('script')->{src})->status_is(200)->content_like(qr{\bVue\b});

done_testing;

__DATA__
@@ index.html.ep
%= asset 'app.js'
