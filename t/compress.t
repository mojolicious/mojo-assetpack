use warnings;
use strict;
use Test::More;
use Test::Mojo;

plan skip_all => 'Not ready for alien host' unless $^O eq 'linux';

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

plan skip_all => 't/public/packed' unless -d 't/public/packed';

my $t = Test::Mojo->new;
my $ts = $^T;

if($assetpack->{preprocessor}{js}) {
  $t->get_ok('/js'); # trigger pack_javascripts() twice for coverage
  $t->get_ok('/js')
    ->status_is(200)
    ->content_like(qr{<script src="/packed/app\.$ts\.js".*}m)
    ;
  $t->get_ok("/packed/app.$ts.js")
    ->status_is(200)
    ->content_like(qr{["']a["'].*["']b["']}s)
    ;
}

if($assetpack->{preprocessor}{less}) {
  $t->get_ok('/less'); # trigger pack_stylesheets() twice for coverage
  $t->get_ok('/less')
    ->status_is(200)
    ->content_like(qr{<link href="/packed/less\.$ts\.css".*}m)
    ;
  $t->get_ok("/packed/less.$ts.css")
    ->status_is(200)
    ->content_like(qr{a1a1a1.*b1b1b1}s)
    ;
}

if($assetpack->{preprocessor}{scss}) {
  $t->get_ok('/sass')
    ->status_is(200)
    ->content_like(qr{<link href="/packed/sass\.$ts\.css".*}m)
    ;
  $t->get_ok("/packed/sass.$ts.css")
    ->status_is(200)
    ->content_like(qr{a1a1a1.*b1b1b1}s)
    ;
}

{
  $t->get_ok('/css')
    ->status_is(200)
    ->content_like(qr{<link href="/packed/app\.$ts\.css".*}m)
    ;
  $t->get_ok("/packed/app.$ts.css")
    ->status_is(200)
    ->content_like(qr{c1c1c1.*d1d1d1})
    ;
}

done_testing;
__DATA__
@@ js.html.ep
%= asset 'app.js'
@@ less.html.ep
%= asset 'less.css'
@@ sass.html.ep
%= asset 'sass.css'
@@ css.html.ep
%= asset 'app.css'
