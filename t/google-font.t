use t::Helper;
my $t = t::Helper->t;

plan skip_all => 'TEST_ONLINE=1' unless $ENV{TEST_ONLINE} or -e '.test-everything';

$t->app->asset->process(
  'app.css' => 'https://fonts.googleapis.com/css?family=Roboto:400,700');
$t->get_ok('/')->status_is(200);

# comment from https://github.com/hugeinc/flexboxgrid-sass/blob/master/demo/sass/_code.scss
$t->get_ok($t->tx->res->dom->at('link')->{href})->status_is(200)
  ->header_is('Content-Type', 'text/css')->content_like(qr{Roboto}s);

my $cache_file = File::Spec->catfile(
  qw(t assets cache fonts.googleapis.com css_family_Roboto_400_700));
ok -e $cache_file, 'cache file does not contain weird characters';

done_testing;

__DATA__
@@ index.html.ep
%= asset 'app.css'
