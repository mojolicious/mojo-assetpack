use t::Helper;
plan skip_all => 'TEST_ONLINE=1' unless $ENV{TEST_ONLINE} or -e '.test-everything';
plan skip_all => 'cpanm CSS::Sass' unless eval 'require CSS::Sass;1';

my $t = t::Helper->t(pipes => [qw(Sass Css Combine)]);
$t->app->asset->process;

$t->get_ok('/')->status_is(200)
  ->element_exists(qq(link[href="/asset/7f7e3e4ecf/main.css"]));

# comment from https://github.com/hugeinc/flexboxgrid-sass/blob/master/demo/sass/_code.scss
$t->get_ok($t->tx->res->dom->at('link')->{href})->status_is(200)
  ->content_unlike(qr{Tomorrow.*Tomorrow}s)->content_like(qr{Tomorrow Theme}s);

$ENV{MOJO_MODE} = 'Test_minify_from_here';
$t = t::Helper->t(pipes => [qw(Sass Css Combine)]);
$t->app->asset->process;

$t->get_ok('/')->status_is(200)
  ->element_exists(qq(link[href="/asset/3c8a6b9b5d/app.css"]));

# comment from https://github.com/hugeinc/flexboxgrid-sass/blob/master/demo/sass/_code.scss
$t->get_ok($t->tx->res->dom->at('link')->{href})->status_is(200)
  ->content_unlike(qr{Tomorrow.*Tomorrow}s)->content_like(qr{Tomorrow Theme}s);

unlink File::Spec->catfile(split '/')
  for (
  't/assets/cache/raw.githubusercontent.com/hugeinc/flexboxgrid-sass/master/demo/sass/demo.scss',
  't/assets/cache/raw.githubusercontent.com/hugeinc/flexboxgrid-sass/master/demo/sass/_code.scss',
  );

done_testing;

__DATA__
@@ index.html.ep
%= asset 'app.css'
@@ assetpack.def
! app.css
<< https://raw.githubusercontent.com/hugeinc/flexboxgrid-sass/master/demo/sass/demo.scss
< sass/main.scss
@@ sass/main.scss
@import "cache/raw.githubusercontent.com/hugeinc/flexboxgrid-sass/master/demo/sass/_code.scss";
