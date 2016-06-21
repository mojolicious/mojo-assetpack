use t::Helper;

plan skip_all => 'TEST_ONLINE=1' unless $ENV{TEST_ONLINE} or -e '.test-everything';

my $t = t::Helper->t(pipes => [qw(Css Fetch)]);
$t->app->asset->process('app.css' => 'http://harvesthq.github.io/chosen/chosen.css');

$t->get_ok('/')->status_is(200);
$t->get_ok($t->tx->res->dom->at('link')->{href})->status_is(200)
  ->content_like(qr{\Q../../\Easset/\w+/chosen-sprite\.png'?\)})
  ->content_like(qr{\Q../../\Easset/\w+/chosen-sprite\@2x\.png'?\)})
  ->content_unlike(qr{\Qurl('chosen-sprite.png')\E});

done_testing;

__DATA__
@@ index.html.ep
%= asset 'app.css'
Hello world
