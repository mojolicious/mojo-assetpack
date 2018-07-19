use lib '.';
use t::Helper;

plan skip_all => 'cpanm JavaScript::Minifier::XS'
  unless eval 'require JavaScript::Minifier::XS;1';
plan skip_all => 'TEST_RIOTJS=1' unless $ENV{TEST_RIOTJS} or -e '.test-everything';

my $t = t::Helper->t(pipes => [qw(Riotjs JavaScript)]);
$t->app->asset->process('app.js' => ('r1.tag'));
$t->get_ok('/')->status_is(200)
  ->element_exists(qq(script[src="/asset/7373328564/r1.js"]));

$t->get_ok($t->tx->res->dom->at('script')->{src})->status_is(200)
  ->content_like(qr{^\s*riot\.tag.*onclick=.*"foo";\n\s+this\.clicked.*\);\s*}s);

$ENV{MOJO_MODE} = 'Test_minify_from_here';
$t = t::Helper->t(pipes => [qw(Riotjs JavaScript)]);
$t->app->asset->process('app.js' => ('r1.tag'));
$t->get_ok('/')->status_is(200)
  ->element_exists(qq(script[src="/asset/7373328564/r1.js"]));

$t->get_ok($t->tx->res->dom->at('script')->{src})->status_is(200)
  ->content_like(qr{"foo";this\.clicked});

done_testing;

__DATA__
@@ index.html.ep
%= asset 'app.js'
@@ r1.tag
<custom-tag>
  <div>
    <button onclick={clicked}>{text}</button>
  </div>
  <script>
  this.text = "foo";

  clicked(e) {
    console.log(e.target);
  }
  </script>
</custom-tag>
