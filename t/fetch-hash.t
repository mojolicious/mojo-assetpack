use lib '.';
use t::Helper;

plan skip_all => 'TEST_ONLINE=1' unless $ENV{TEST_ONLINE} or -e '.test-everything';

my $t = t::Helper->t(pipes => [qw(Css Fetch)]);
$t->app->asset->process(
  'app.css' => 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.0.1/leaflet.css');

$t->get_ok('/')->status_is(200);
$t->get_ok($t->tx->res->dom->at('link')->{href})->status_is(200)
  ->content_like(qr{url\(\#default\#VML\)});

done_testing;

__DATA__
@@ index.html.ep
%= asset 'app.css'
Hello world
