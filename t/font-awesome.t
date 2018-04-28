use lib '.';
use t::Helper;

plan skip_all => 'TEST_ONLINE=1' unless $ENV{TEST_ONLINE} or -e '.test-everything';

my $t = t::Helper->t(pipes => [qw(Css Fetch)]);
$t->app->asset->process('app.css' =>
    'https://maxcdn.bootstrapcdn.com/font-awesome/4.5.0/css/font-awesome.min.css');

$t->get_ok('/')->status_is(200);
$t->get_ok($t->tx->res->dom->at('link')->{href})->status_is(200)
  ->content_like(qr{\Qurl('../../asset/1f77ee43a2/fontawesome-webfont_v_4_5_0.eot')\E})
  ->content_like(qr{\Qurl('../../asset/b32f30f455/fontawesome-webfont_v_4_5_0.ttf')\E});

$t->get_ok('/asset/1f77ee43a2/fontawesome-webfont_v_4_5_0.eot')->status_is(200);

$ENV{MOJO_MODE} = 'production';
$t = t::Helper->t(pipes => [qw(Css Fetch Combine)]);
$t->app->asset->process('app.css' =>
    'https://maxcdn.bootstrapcdn.com/font-awesome/4.5.0/css/font-awesome.min.css');

$t->get_ok('/')->status_is(200);
$t->get_ok($t->tx->res->dom->at('link')->{href})->status_is(200)
  ->content_like(qr{\Qurl('../../asset/1f77ee43a2/fontawesome-webfont_v_4_5_0.eot')\E})
  ->content_like(qr{\Qurl('../../asset/b32f30f455/fontawesome-webfont_v_4_5_0.ttf')\E});

$t->get_ok('/asset/1f77ee43a2/fontawesome-webfont_v_4_5_0.eot')->status_is(200);

done_testing;

__DATA__
@@ index.html.ep
%= asset 'app.css'
<i class="fa fa-camera-retro" aria-hidden="true"></i> fa-camera-retro
