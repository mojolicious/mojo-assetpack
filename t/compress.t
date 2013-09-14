use warnings;
use strict;
use Test::More;
use Test::Mojo;

plan skip_all => 'Not ready for alien host' unless $^O eq 'linux';

{
  use Mojolicious::Lite;
  plugin 'AssetPack' => {
    enable => 1,
    reset => 1,
  };

  app->asset('app.js' => '/js/a.js', '/js/b.js');
  app->asset('less.css' => '/css/a.less', '/css/b.less');
  app->asset('sass.css' => '/css/a.scss', '/css/b.scss');
  app->asset('app.css' => '/css/c.css', '/css/d.css');

  get '/js' => 'js';
  get '/less' => 'less';
  get '/sass' => 'sass';
  get '/css' => 'css';
}

plan skip_all => 't/public/packed' unless -d 't/public/packed';
my $t = Test::Mojo->new;

if($Mojolicious::Plugin::AssetPack::APPLICATIONS{js}) {
  $t->get_ok('/js'); # trigger pack_javascripts() twice for coverage
  $t->get_ok('/js')
    ->status_is(200)
    ->content_like(qr{<script src="/packed/app\.js".*}m)
    ;
}

if($Mojolicious::Plugin::AssetPack::APPLICATIONS{less}) {
  $t->get_ok('/less'); # trigger pack_stylesheets() twice for coverage
  $t->get_ok('/less')
    ->status_is(200)
    ->content_like(qr{<link href="/packed/less\.css".*}m)
    ;
}

if($Mojolicious::Plugin::AssetPack::APPLICATIONS{scss}) {
  $t->get_ok('/sass')
    ->status_is(200)
    ->content_like(qr{<link href="/packed/sass\.css".*}m)
    ;
}

{
  $t->get_ok('/css')
    ->status_is(200)
    ->content_like(qr{<link href="/packed/app\.css".*}m)
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
