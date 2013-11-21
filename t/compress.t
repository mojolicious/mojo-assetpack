use warnings;
use strict;
use Test::More;
use Test::Mojo;

plan skip_all => 'Not ready for alien host' unless $^O eq 'linux';
plan tests => 26;

unlink glob 't/public/packed/*';

my $assetpack;

{
  use Mojolicious::Lite;
  plugin 'AssetPack' => { minify => 1 };

  app->asset('app.js' => '/js/a.js', '/js/b.js');
  app->asset('app.css' => '/css/c.css', '/css/d.css');
  $assetpack = app->asset;

  get '/js' => 'js';
  get '/less' => 'less';
  get '/sass' => 'sass';
  get '/css' => 'css';
}

my $t = Test::Mojo->new;

{
  $t->get_ok('/js'); # trigger pack_javascripts() twice for coverage
  $t->get_ok('/js')
    ->status_is(200)
    ->content_like(qr{<script src="/packed/app-8072d187db8ff7a1809b88ae1a5f3bd7\.js".*}m)
    ;
  $t->get_ok($t->tx->res->dom->at('script')->{src})
    ->status_is(200)
    ->content_like(qr{["']a["'].*["']b["']}s)
    ;
}

SKIP: {
  skip 'Could not find preprocessors for less', 7 unless $assetpack->preprocessors->has_subscribers('less');
  $t->app->asset('less.css' => '/css/a.less', '/css/b.less');
  $t->get_ok('/less'); # trigger pack_stylesheets() twice for coverage
  $t->get_ok('/less')
    ->status_is(200)
    ->content_like(qr{<link href="/packed/less-8dd04d9b9e50ace10e29f7c5d0b2b39d\.css".*}m)
    ;
  $t->get_ok($t->tx->res->dom->at('link')->{href})
    ->status_is(200)
    ->content_like(qr{a1a1a1.*b1b1b1}s)
    ;
}

SKIP: {
  skip 'Could not find preprocessors for scss', 6 unless $assetpack->preprocessors->has_subscribers('scss');
  $t->app->asset('sass.css' => '/css/a.scss', '/css/b.scss');
  $t->get_ok('/sass')
    ->status_is(200)
    ->content_like(qr{<link href="/packed/sass-3041fa396995aff3acc7b926cc8981b2\.css".*}m)
    ;
  $t->get_ok($t->tx->res->dom->at('link')->{href})
    ->status_is(200)
    ->content_like(qr{a1a1a1.*b1b1b1}s)
    ;
}

{
  $t->get_ok('/css')
    ->status_is(200)
    ->content_like(qr{<link href="/packed/app-9113e4a5ae6bad4b3c8343549984ae3d\.css".*}m)
    ;
  $t->get_ok($t->tx->res->dom->at('link')->{href})
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
