use t::Helper;

my $t = t::Helper->t_old({minify => 1});

$t->app->asset('style.css' => '/css/a.css', '/css/b.css');
$t->app->asset('script.js' => '/js/a.js',   '/js/b.js');

$t->get_ok('/test1')->status_is(200)->element_exists('link')->element_exists('style[id="id24"]')
  ->element_exists('link[rel="stylesheet"][href^="/packed/style-"][media="print,handheld,embossed"]')
  ->element_exists('link[rel="stylesheet"][href^="/packed/style-"]')
  ->element_exists('script[id="id42"][src^="/packed/script-"]');

done_testing;
__DATA__
@@ test1.html.ep
%= asset "style.css"
%= asset "style.css", {inline => 1}, id => "id24"
%= asset "style.css", {}, media => "print,handheld,embossed"
%= asset "script.js", {}, id => "id42"
