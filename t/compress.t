use warnings;
use strict;
use Test::More;
use Test::Mojo;

plan skip_all => 'Not ready for alien host' unless $^O eq 'linux';
plan tests => 26;

my $assetpack;

{
  use Mojolicious::Lite;
  plugin 'AssetPack' => { minify => 1, rebuild => 1 };

  app->asset('app.js' => '/js/a.js', '/js/b.js');
  app->asset('less.css' => '/css/a.less', '/css/b.less');
  app->asset('sass.css' => '/css/a.scss', '/css/b.scss');
  app->asset('app.css' => '/css/c.css', '/css/d.css');
  $assetpack = app->asset;

  get '/js' => 'js';
  get '/less' => 'less';
  get '/sass' => 'sass';
  get '/css' => 'css';
}

my $t = Test::Mojo->new;

SKIP: {
  skip 'Could not find preprocessors for js', 7 unless $assetpack->preprocessors->has_subscribers('js');
  $t->get_ok('/js'); # trigger pack_javascripts() twice for coverage
  $t->get_ok('/js')
    ->status_is(200)
    ->content_like(qr{<script src="/packed/app-d2e6677cf8beb95274597f3836ea12e9\.js".*}m)
    ;
  $t->get_ok("/packed/app-d2e6677cf8beb95274597f3836ea12e9.js")
    ->status_is(200)
    ->content_like(qr{["']a["'].*["']b["']}s)
    ;
}

SKIP: {
  skip 'Could not find preprocessors for less', 7 unless $assetpack->preprocessors->has_subscribers('less');
  $t->get_ok('/less'); # trigger pack_stylesheets() twice for coverage
  $t->get_ok('/less')
    ->status_is(200)
    ->content_like(qr{<link href="/packed/less-bc18bba8ec99a2b755fb7b42a0dd0474\.css".*}m)
    ;
  $t->get_ok("/packed/less-bc18bba8ec99a2b755fb7b42a0dd0474.css")
    ->status_is(200)
    ->content_like(qr{a1a1a1.*b1b1b1}s)
    ;
}

SKIP: {
  skip 'Could not find preprocessors for scss', 6 unless $assetpack->preprocessors->has_subscribers('scss');
  $t->get_ok('/sass')
    ->status_is(200)
    ->content_like(qr{<link href="/packed/sass-a57106dcfcd43c44c48d4b9fabf9c817\.css".*}m)
    ;
  $t->get_ok("/packed/sass-a57106dcfcd43c44c48d4b9fabf9c817.css")
    ->status_is(200)
    ->content_like(qr{a1a1a1.*b1b1b1}s)
    ;
}

SKIP: {
  skip 'Could not find preprocessors for css', 6 unless $assetpack->preprocessors->has_subscribers('css');
  $t->get_ok('/css')
    ->status_is(200)
    ->content_like(qr{<link href="/packed/app-23872cd4e53e8bb7172460bf48c5f4d8\.css".*}m)
    ;
  $t->get_ok("/packed/app-23872cd4e53e8bb7172460bf48c5f4d8.css")
    ->status_is(200)
    ->content_like(qr{c1c1c1.*d1d1d1})
    ;
}

__DATA__
@@ js.html.ep
%= asset 'app.js'
@@ less.html.ep
%= asset 'less.css'
@@ sass.html.ep
%= asset 'sass.css'
@@ css.html.ep
%= asset 'app.css'
