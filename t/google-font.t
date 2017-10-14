use lib '.';
use t::Helper;

plan skip_all => 'TEST_ONLINE=1' unless $ENV{TEST_ONLINE} or -e '.test-everything';

my $t1 = t::Helper->t(pipes => [qw(Css Fetch)]);
$t1->app->asset->process(
  'app.css' => 'https://fonts.googleapis.com/css?family=Roboto:400,700');
$t1->get_ok('/')->status_is(200);

# comment from https://github.com/hugeinc/flexboxgrid-sass/blob/master/demo/sass/_code.scss
$t1->get_ok($t1->tx->res->dom->at('link')->{href})->status_is(200)
  ->header_is('Content-Type', 'text/css')->content_like(qr{font-family:\W*Roboto})
  ->content_like(qr{\Qurl(../../asset/\E\w+/.*\.ttf\)});

my $cache_file = File::Spec->catfile(
  qw(t assets cache fonts.googleapis.com css_family_Roboto_400_700.css));
ok -e $cache_file, 'cache file does not contain weird characters';

Mojo::Util::monkey_patch('Mojo::UserAgent',
  'get' => sub { shift; die "Should get font from cache! @_" });
my $t2 = t::Helper->t(pipes => [qw(Css Fetch)]);
$t2->app->asset->process(
  'app.css' => 'http://fonts.googleapis.com/css?family=Roboto:400,700');
$t2->get_ok('/');
$t2->get_ok($t2->tx->res->dom->at('link')->{href})->status_is(200)
  ->header_is('Content-Type', 'text/css')->content_like(qr{font-family:\W*Roboto});

my $t3 = t::Helper->t(pipes => [qw(Css Fetch)]);

is_deeply($t2->app->asset->store->_db, {}, 'nothing stored in db file (t2)');
is_deeply($t3->app->asset->store->_db, {}, 'nothing stored in db file (t3)');

done_testing;

__DATA__
@@ index.html.ep
%= asset 'app.css'
