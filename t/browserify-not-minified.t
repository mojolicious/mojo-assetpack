use t::Helper;
use Mojolicious::Plugin::AssetPack::Preprocessor::Browserify;

my $p = Mojolicious::Plugin::AssetPack::Preprocessor::Browserify->new;

plan skip_all => 'npm install module-deps' unless eval { $p->_install_node_module('module-deps') };

my $t = t::Helper->t({});
ok !$t->app->asset->minify, 'not minify';
$t->app->asset->preprocessor(Browserify => {environment => 'development', extensions => ['js']});

$t->app->asset('app.js'    => '/js/boop.js');
$t->app->asset('parent.js' => '/js/ctrl.js');

$t->get_ok('/test1')->status_is(200)->content_like(qr{s\.toUpperCase\(.*'\!'}, 'robot.js')
  ->content_like(qr{console\.log\(robot\('boop'\)\);}, 'boop.js');

done_testing;

__DATA__
@@ test1.html.ep
%= asset "app.js" => {inline => 1}
%= asset "parent.js" => {inline => 1}
