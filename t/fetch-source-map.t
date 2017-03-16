use lib '.';
use t::Helper;

plan skip_all => 'TEST_ONLINE=1' unless $ENV{TEST_ONLINE} or -e '.test-everything';

my $t = t::Helper->t(pipes => [qw(JavaScript Fetch)]);
$t->app->asset->process('app.js' => 'https://cdnjs.cloudflare.com/ajax/libs/angular.js/1.6.1/angular.min.js');

$t->get_ok('/')->status_is(200);
$t->get_ok($t->tx->res->dom->at('link')->{href})->status_is(200)
  ->content_like(qr{sourceMappingURL=../../asset/\w+/angular\.min\.js\.map});

done_testing;

__DATA__
@@ index.html.ep
%= asset 'app.js'
