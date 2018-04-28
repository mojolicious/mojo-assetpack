use lib '.';
use t::Helper;

plan skip_all => 'TEST_ONLINE=1' unless $ENV{TEST_ONLINE};

my $t = t::Helper->t(pipes => [qw(Css Fetch)]);
$t->app->asset->process(
  'app.css' => 'http://code.jquery.com/mobile/1.4.5/jquery.mobile-1.4.5.css');
$t->get_ok('/')->status_is(200);

$t->get_ok($t->tx->res->dom->at('link')->{href})->status_is(200)
  ->content_like(qr{\Qurl(../../asset/b066a0df42/ajax-loader.gif)\E});

done_testing;

__DATA__
@@ index.html.ep
%= asset 'app.css'
