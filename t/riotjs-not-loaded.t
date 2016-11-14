use lib '.';
use t::Helper;

my $t = t::Helper->t(pipes => ['Css']);
$t->app->asset->process('app.js' => ('r1.tag'));
$t->get_ok('/')->status_is(200)
  ->element_exists(qq(link[href="/asset/7373328564/r1.tag"]));

$t->get_ok($t->tx->res->dom->at('link')->{href})->status_is(200)
  ->header_is('Content-Type', 'text/css')
  ->content_like(qr{content:'"r1.tag" is not processed.';}s);

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
