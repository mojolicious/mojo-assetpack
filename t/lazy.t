BEGIN { $ENV{MOJO_ASSETPACK_LAZY} = 1 }
use lib '.';
use t::Helper;
plan skip_all => 'cpanm CSS::Sass' unless eval 'use CSS::Sass 3.3.0;1';

my $t = t::Helper->t(pipes => [qw(Sass Css)]);

$t->app->asset->process('app.css' => ('sass-one.sass', 'sass-two.scss'));
$t->get_ok('/asset/5660087922/sass-one.css')->status_is(404, 'not yet compiled');

$t->get_ok('/')->status_is(200)
  ->element_exists(qq(link[href="/asset/5660087922/sass-one.css"]))
  ->element_exists(qq(link[href="/asset/9f0d8f784a/sass-two.css"]));

$t->get_ok('/asset/5660087922/sass-one.css')->status_is(200)
  ->content_like(qr{\.sass\W+color:\s+\#aaa}s);
$t->get_ok('/asset/9f0d8f784a/sass-two.css')->status_is(200)
  ->content_like(qr{body\W+background:\s*\#fff.*\.scss \.nested\W+color:\s+\#9\d9\d9\d}s);

Mojo::Loader::data_section('main')->{'sass-two.scss'} = 'body { background: black; }';
$t->get_ok('/')->status_is(200)
  ->element_exists(qq(link[href="/asset/5660087922/sass-one.css"]))
  ->element_exists(qq(link[href="/asset/0dfb452e32/sass-two.css"]))
  ->element_exists_not(qq(link[href="/asset/9f0d8f784a/sass-two.css"]));

{
  local $TODO = 'Not sure if we need to clear out old checksums';
  $t->get_ok('/asset/9f0d8f784a/sass-two.css')->status_is(404);
}

$t->get_ok('/asset/0dfb452e32/sass-two.css')->status_is(200)
  ->content_like(qr{body\W+background:\s*black}s);

$t = t::Helper->t(pipes => [qw(Css Fetch)]);
is_deeply($t->app->asset->store->_db, {}, 'nothing was stored in db');

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
