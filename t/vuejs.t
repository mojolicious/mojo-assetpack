BEGIN { $ENV{MOJO_MODE} = 'not_development' }
use t::Helper;

my $t = t::Helper->t(pipes => ['Vuejs']);

$t->app->asset->process('app.js' => 'vue/example.vue');

$t->get_ok('/')->status_is(200)
  ->element_exists(qq(script[src="/asset/23d7a115e2/example.js"]));

$t->get_ok($t->tx->res->dom->at('script')->{src})->status_is(200)
  ->content_like(qr[^\Q(function(){\E],        'starts with function')
  ->content_like(qr[\Q)})();\E],               'ends with calling function')
  ->content_like(qr[\Qvar initial = false;\E], 'var initial')
  ->content_like(qr[\QVue.component("example"\E.*data:.*methods:.*template:.*\);]s, 'vue')
  ->content_like(qr[\Q\"loading\"\E], 'quotes espcaped in template');

done_testing;

__DATA__
@@ index.html.ep
%= asset 'app.js'
