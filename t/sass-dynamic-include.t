use lib '.';
use t::Helper;
plan skip_all => 'cpanm CSS::Sass' unless eval 'use CSS::Sass 3.3.0;1';

my $t = t::Helper->t(pipes => ['Sass']);

$t->app->routes->get(
  '/_dynamic' => [format => 'scss'],
  sub {
    shift->render(text => "\$color: black;\n");
  }
);

$t->app->asset->process('app.css' => 'dynamic.scss');
$t->get_ok('/')->status_is(200);
$t->get_ok($t->tx->res->dom->at('link')->{href})->status_is(200)
  ->content_like(qr{body.*black}s);

done_testing;

__DATA__
@@ index.html.ep
%= asset 'app.css'
@@ dynamic.scss
@import "http://local/dynamic";
$color: red !default;
body { color: $color; }
