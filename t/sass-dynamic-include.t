use lib '.';
use t::Helper;
plan skip_all => 'cpanm CSS::Sass' unless eval 'use CSS::Sass 3.3.0;1';

my $t = t::Helper->t(pipes => ['Sass']);

$t->app->routes->get(
  '/custom/asset/sass/variables' => [format => 'scss'],
  sub {
    shift->render(text => "\$color: black;\n");
  }
);

$t->app->asset->process('app.css' => 'dynamic.scss');
$t->get_ok('/')->status_is(200);
$t->get_ok($t->tx->res->dom->at('link')->{href})->status_is(200)
  ->content_unlike(qr{\@import})->content_like(qr{body.*black}s);

done_testing;

__DATA__
@@ index.html.ep
%= asset 'app.css'
@@ dynamic.scss
@charset "UTF-8";
// @import "skip/this";
// Variables
@import "http://local/custom/asset/sass/variables.scss"; // special case that AssetPack handles
$color: red !default;
body { color: $color; }
