use lib '.';
use t::Helper;

$ENV{MOJO_MODE} = 'development';

my $app = Mojolicious->new;
$app->plugin(AssetPack => {pipes => [qw(Css Combine)]});
$app->asset->process;
$app->routes->get('/' => 'index');

my $t = Test::Mojo->new(Mojolicious->new);
$t->app->routes->route('/mounted')->detour(app => $app);
$t->get_ok('/')->status_is(404);
$t->get_ok('/mounted')->status_is(200)->element_exists('link[href="/mounted/asset/5524d15cbb/foo.css"]');
$t->get_ok($t->tx->res->dom->at('link')->{href})->status_is(200);

done_testing;

__DATA__
@@ index.html.ep
%= asset 'app.css'
@@ assetpack.def
! app.css
< foo.css
@@ foo.css
.foo { color: #333 }
