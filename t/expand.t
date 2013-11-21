use warnings;
use strict;
use Test::More;
use Test::Mojo;

plan skip_all => 'Not ready for alien host' unless $^O eq 'linux';
plan tests => 20;

my $assetpack;

{
  use Mojolicious::Lite;
  plugin 'AssetPack';

  app->asset('app.js' => '/js/a.js', '/js/b.js');
  app->asset('less.css' => '/css/a.less', '/css/b.less');
  app->asset('sass.css' => '/css/a.scss', '/css/b.scss');
  app->asset('app.css' => '/css/a.css', '/css/b.css');
  $assetpack = app->asset;

  get '/js' => 'js';
  get '/less' => 'less';
  get '/sass' => 'sass';
  get '/css' => 'css';
  get '/undefined' => 'undefined';
}

my $t = Test::Mojo->new;

{
  $t->get_ok('/js')
    ->status_is(200)
    ->content_like(qr{<script src="/js/a\.js".*<script src="/js/b\.js"}s)
    ;

  is_deeply(
    [ app->asset->get('app.js') ],
    [ '/js/a.js', '/js/b.js' ],
    'get(app.js)'
  );
}

SKIP: {
  skip 'Could not find preprocessors for less', 3 unless $assetpack->preprocessors->has_subscribers('less');
  $t->get_ok('/less')
    ->status_is(200)
    ->content_like(qr{<link href="/css/a\.css".*<link href="/css/b\.css"}s)
    ;
}

SKIP: {
  skip 'Could not find preprocessors for scss', 3 unless $assetpack->preprocessors->has_subscribers('scss');
  $t->get_ok('/sass')
    ->status_is(200)
    ->content_like(qr{<link href="/css/a\.css".*<link href="/css/b\.css"}s)
    ;
}

{
  $t->get_ok('/css')
    ->status_is(200)
    ->content_like(qr{<link href="/css/a\.css".*<link href="/css/b\.css"}s)
    ;
}

{
  $t->get_ok('/undefined')
    ->status_is(200)
    ->content_like(qr{<!-- Could not expand});
    ;
}

{
  $t->get_ok('/css/a.css')->content_like(qr{a1a1a1;});
  $t->get_ok('/css/b.css')->content_like(qr{b1b1b1;});
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
@@ undefined.html.ep
%= asset 'undefined.css'
