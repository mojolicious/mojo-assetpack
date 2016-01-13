use t::Helper;
my $t = t::Helper->t;

plan skip_all => 'cpanm CSS::Sass' unless eval 'require CSS::Sass;1';

$t->app->asset->process('app.css' => ('sass-0-one.sass', 'sass-0-two.scss'));
$t->get_ok('/')->status_is(200)
  ->element_exists(qq(link[href="/asset/5660087922/sass-0-one.css"]))
  ->element_exists(qq(link[href="/asset/df9ab2c3d8/sass-0-two.css"]));

my $html = $t->tx->res->dom;
$t->get_ok($html->at('link:nth-of-child(1)')->{href})->status_is(200)
  ->content_like(qr{\.sass\W+color:\s+\#aaa}s);
$t->get_ok($html->at('link:nth-of-child(2)')->{href})->status_is(200)
  ->content_like(qr{body\W+background:.*\.scss \.nested\W+color:\s+\#909090}s);

done_testing;

__DATA__
@@ index.html.ep
%= asset 'app.css'
@@ sass-0-one.sass
$color: #aaa;
.sass
  color: $color;
@@ sass-0-two.scss
@import "sass-0-include";
$color: #aaa;
.scss {
  color: $color;
  .nested { color: darken($color, 10%); }
}
@@ sass-0-include.scss
body { background: #fff; }
