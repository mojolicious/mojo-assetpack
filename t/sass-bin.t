use lib '.';
use t::Helper;
plan skip_all => 'TEST_SASS=1' unless $ENV{TEST_SASS} or -e '.test-everything';

my $t    = t::Helper->t(pipes => [qw(Sass Css)]);
my $sass = $t->app->asset->pipe('Sass');
isa_ok($sass, 'Mojolicious::Plugin::AssetPack::Pipe::Sass');
$sass->{has_module} = '';    # make sure CSS::Sass is not used

$t->app->asset->process('app.css' => ('sass.sass', 'sass/sass-1.scss'));
$t->get_ok('/')->status_is(200)->element_exists(qq(link[href="/asset/8d347a7a6f/sass.css"]))
  ->element_exists(qq(link[href="/asset/71dcf0669a/sass-1.css"]));

my $html = $t->tx->res->dom;
$t->get_ok($html->at('link:nth-of-child(1)')->{href})->status_is(200)->content_like(qr{\.sass\W+color:\s+\#aaa}s);

$t->get_ok($html->at('link:nth-of-child(2)')->{href})->status_is(200)->content_like(qr{footer.*\#aaa.*body.*\#222}s);

$ENV{MOJO_MODE} = 'Test_minify_from_here';
$t = t::Helper->t(pipes => [qw(Sass Css Combine)]);
$t->app->asset->pipe('Sass')->{has_module} = '';    # make sure CSS::Sass is not used
$t->app->asset->process('app.css' => ('sass.sass', 'sass/sass-1.scss'));
$t->get_ok('/')->status_is(200);
$t->get_ok($t->tx->res->dom->at('link')->{href})->status_is(200)->content_unlike(qr/[ ]/)
  ;                                                 # No spaces in minified version

done_testing;

__DATA__
@@ index.html.ep
%= asset 'app.css'
@@ sass.sass
$color: #aaa
.sass
  color: $color
