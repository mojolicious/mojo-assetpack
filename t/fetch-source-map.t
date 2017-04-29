use lib '.';
use t::Helper;

plan skip_all => 'TEST_ONLINE=1' unless $ENV{TEST_ONLINE} or -e '.test-everything';

my $t = t::Helper->t(pipes => ['Fetch']);
$t->app->asset->process(
  'app.js' => 'https://cdnjs.cloudflare.com/ajax/libs/angular.js/1.6.1/angular.min.js');

$t->get_ok('/')->status_is(200);
$t->get_ok($t->tx->res->dom->at('script')->{src})->status_is(200)
  ->content_like(qr{\QsourceMappingURL=../../asset/0bf00b0aa8/angular.min.js.map\E});

$t->get_ok('/asset/0bf00b0aa8/angular.min.js.map')->status_is(200);

$ENV{MOJO_ASSETPACK_CLEANUP} = 0;
$ENV{MOJO_MODE}              = 'production';
$t = t::Helper->t(pipes => [qw(Fetch Combine)]);
$t->app->asset->process(
  'app.js' => 'https://cdnjs.cloudflare.com/ajax/libs/angular.js/1.6.1/angular.min.js');

$t->get_ok('/')->status_is(200);
$t->get_ok($t->tx->res->dom->at('script')->{src})->status_is(200)
  ->content_like(qr{\QsourceMappingURL=../../asset/0bf00b0aa8/angular.min.js.map\E});

$t->get_ok('/asset/0bf00b0aa8/angular.min.js.map')->status_is(200);

$ENV{MOJO_ASSETPACK_CLEANUP} = 1;

done_testing;

__DATA__
@@ index.html.ep
%= asset 'app.js'
