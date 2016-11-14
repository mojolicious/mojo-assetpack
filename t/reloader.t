use lib '.';
use t::Helper;

my $file = Mojo::Asset::File->new(path => 't/assets/t-reloader.css');
eval { $file->add_chunk("body{color:#000;}\n") } or plan skip_all => "t-reloader.css: $!";

my $t = t::Helper->t(pipes => [qw(Reloader Css Combine)]);
my $asset = $t->app->asset->store->asset('t-reloader.css');
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

unlink $file->path;

done_testing;
__DATA__
@@ index.html.ep
%= asset 'app.css'
