use t::Helper;
plan skip_all => 'cpanm CSS::Sass' unless eval 'use CSS::Sass 3.3.0;1';

my $t = t::Helper->t(pipes => [qw(Sass Css)]);
$t->app->asset->process('app.css' => ('sass-one.sass', 'sass-two.scss'));
$t->get_ok('/')->status_is(200)
  ->element_exists(qq(link[href="/asset/5660087922/sass-one.css"]))
  ->element_exists(qq(link[href="/asset/9f0d8f784a/sass-two.css"]));

my $html = $t->tx->res->dom;
$t->get_ok($html->at('link:nth-of-child(1)')->{href})->status_is(200)
  ->content_like(qr{\.sass\W+color:\s+\#aaa}s);
$t->get_ok($html->at('link:nth-of-child(2)')->{href})->status_is(200)
  ->content_like(qr{body\W+background:.*\.scss \.nested\W+color:\s+\#9\d9\d9\d}s);

$ENV{MOJO_MODE} = 'Test_minify_from_here';

# Assets from __DATA__
$t = t::Helper->t(pipes => [qw(Sass Css Combine)]);
$t->app->asset->process('app.css' => ('sass-one.sass', 'sass-two.scss'));
$t->get_ok('/')->status_is(200)
  ->element_exists(qq(link[href="/asset/e035274e04/app.css"]));

$t->get_ok($t->tx->res->dom->at('link')->{href})->status_is(200)
  ->content_like(qr{\.sass\W+color:\s+\#aaa.*\.scss \.nested\W+color:\s+\#9\d9\d9\d}s);

Mojo::Util::monkey_patch('CSS::Sass', sass2scss => sub { die 'Nope!' });
$ENV{MOJO_ASSETPACK_CLEANUP} = 0;
$t = t::Helper->t(pipes => [qw(Sass Css Combine)]);
ok eval { $t->app->asset->process('app.css' => ('sass-one.sass', 'sass-two.scss')) },
  'using cached assets'
  or diag $@;
$ENV{MOJO_ASSETPACK_CLEANUP} = 1;

# Assets from disk
$t = t::Helper->t(pipes => [qw(Sass Css Combine)]);
$t->app->asset->process('app.css' => 'sass/sass-1.scss');
$t->get_ok('/')->status_is(200)
  ->element_exists(qq(link[href="/asset/4abbb4a8c8/app.css"]));
$t->get_ok($t->tx->res->dom->at('link')->{href})->status_is(200)
  ->content_like(qr{footer.*\#aaa.*body.*\#222}s);

done_testing;

__DATA__
@@ index.html.ep
%= asset 'app.css'
@@ sass-one.sass
$color: #aaa;
.sass
  color: $color;
@@ sass-two.scss
@import "sass-0-include";
$color: #aaa;
.scss {
  color: $color;
  .nested { color: darken($color, 9%); }
}
@@ sass-0-include.scss
body { background: #fff; }
