use lib '.';
use t::Helper;

plan skip_all => 'TEST_RELOADER=1' unless $ENV{TEST_RELOADER} or -e '.test-everything';

my $file = Mojo::Asset::File->new(path => 't/assets/t-reloader.css');
eval { $file->add_chunk("body{color:#000;}\n") } or plan skip_all => "t-reloader.css: $!";

my $t = t::Helper->t(pipes => [qw(Css Combine Reloader)]);
my $asset = $t->app->asset->store->asset('t-reloader.css');
ok $t->app->asset->pipe('Reloader')->enabled, 'enabled';

$t->app->asset->process('app.css' => $asset);
$t->get_ok('/')->status_is(200)
  ->element_exists(qq(link[href="/asset/36b3e7b800/t-reloader.css"]));
$t->get_ok($t->tx->res->dom->at('link')->{href})->content_is("body{color:#000;}\n");

$t->websocket_ok('/mojo-assetpack-reloader-ws');
Mojo::IOLoop->one_tick;
$file->add_chunk("div{color:#fff;}\n");
$t->finished_ok(1005);

$t->get_ok('/')->status_is(200)
  ->element_exists(qq(link[href="/asset/5958b3a722/t-reloader.css"]));
$t->get_ok($t->tx->res->dom->at('link')->{href})
  ->content_is("body{color:#000;}\ndiv{color:#fff;}\n");

if (eval 'require CSS::Minifier::XS;1') {
  $ENV{MOJO_MODE} = 'whatever';
  $t = t::Helper->t(pipes => [qw(Css Combine Reloader)]);
  ok !$t->app->asset->pipe('Reloader')->enabled, 'disabled';
  $t->app->asset->process('app.css' => $asset);
  $t->get_ok('/')->status_is(200)
    ->element_exists(qq(link[href="/asset/ee9b1ee297/app.css"]));

  $t->get_ok('/mojo-assetpack-reloader-ws')->status_is(404);
  $file->add_chunk("div{color:#456;}\n");
  $t->get_ok('/')->status_is(200)
    ->element_exists(qq(link[href="/asset/ee9b1ee297/app.css"]));
}

unlink $file->path;

done_testing;
__DATA__
@@ index.html.ep
%= asset 'app.css'
