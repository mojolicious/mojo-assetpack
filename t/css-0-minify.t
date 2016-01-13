use t::Helper;
my $t = t::Helper->t;

$t->app->asset->process('app.css' => ('css-0-one.css', 'css-0-two.css'));
$t->get_ok('/')->status_is(200)
  ->element_exists(qq(link[href="/asset/d508287fc7/css-0-one.css"]))
  ->element_exists(qq(link[href="/asset/ec4c05a328/css-0-two.css"]));

$t->get_ok('/asset/d508287fc7/css-0-one.css')->status_is(200);

done_testing;

__DATA__
@@ index.html.ep
%= asset 'app.css'
