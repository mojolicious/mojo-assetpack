use t::Helper;
use Mojolicious::Plugin::AssetPack::Preprocessor::Browserify;

my $p = Mojolicious::Plugin::AssetPack::Preprocessor::Browserify->new;

plan skip_all => 'npm install module-deps' unless eval { $p->_install_node_module('module-deps') };
plan skip_all => 'npm install reactify'    unless eval { $p->_install_node_module('reactify') };

my $t = t::Helper->t({});
$t->app->asset->preprocessor(Browserify => {transformers => ['reactify'], extensions => ['js']});
$t->app->asset('app.js' => '/js/react-complex.js');

$t->get_ok('/test1')->status_is(200)->content_like(qr{require\('\./react-progressbar})
  ->content_like(qr{React = require\('react'\);})->content_like(qr{DOMChildrenOperations});

done_testing;

__DATA__
@@ test1.html.ep
%= asset "app.js" => {inline => 1}
