use warnings;
use strict;
use Test::More;
use Test::Mojo;

plan skip_all => 'Not ready for alien host' unless $^O eq 'linux';

{
  use Mojolicious::Lite;
  plugin 'AssetPack';

  app->asset('app.js' => '/js/a.js', '/js/b.js');
  app->asset('less.css' => '/css/a.less', '/css/b.less');
  app->asset('sass.css' => '/css/a.scss', '/css/b.scss');
  app->asset('app.css' => '/css/a.css', '/css/b.css');

  get '/js' => 'js';
  get '/less' => 'less';
  get '/sass' => 'sass';
  get '/css' => 'css';
}

my $t = Test::Mojo->new;

if($Mojolicious::Plugin::AssetPack::APPLICATIONS{yuicompressor}) {
  $t->get_ok('/js')
    ->status_is(200)
    ->content_like(qr{<script src="/js/a\.js".*<script src="/js/b\.js"}m)
    ;
}

if($Mojolicious::Plugin::AssetPack::APPLICATIONS{less}) {
  $t->get_ok('/less')
    ->status_is(200)
    ->content_like(qr{<link href="/css/a\.css".*<link href="/css/b\.css"}m)
    ;
}

if($Mojolicious::Plugin::AssetPack::APPLICATIONS{sass}) {
  $t->get_ok('/sass')
    ->status_is(200)
    ->content_like(qr{<link href="/css/a\.css".*<link href="/css/b\.css"}m)
    ;
}

{
  $t->get_ok('/css')
    ->status_is(200)
    ->content_like(qr{<link href="/css/a\.css".*<link href="/css/b\.css"}m)
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
