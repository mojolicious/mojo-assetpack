use warnings;
use strict;
use Test::More;
use Test::Mojo;

plan skip_all => 'Not ready for alien host' unless $^O eq 'linux';
plan tests => 7;

unlink glob 't/public/packed/*';

my $assetpack;
my $url_prefix = 'http://static.app.com';


{
  use Mojolicious::Lite;
  plugin 'AssetPack' => { minify => 0, url_prefix => $url_prefix };

  app->asset('app.css' => '/css/a.css', '/css/b.css');
  app->asset('app.js' => '/js/a.js', '/js/b.js');
  $assetpack = app->asset;

  get '/js' => 'js';
  get '/css' => 'css';
}

my $t = Test::Mojo->new;

{
  $t->get_ok('/js')
    ->status_is(200)
    ->content_like(qr{<script src="$url_prefix/js/a\.js".*<script src="$url_prefix/js/b\.js"}s)
    ;
}

{
  $t->get_ok('/css')
    ->status_is(200)
    ->content_like(qr{<link href="$url_prefix/css/a\.css".*<link href="$url_prefix/css/b\.css"}s)
    ;
}


__DATA__
@@ js.html.ep
%= asset 'app.js'
@@ css.html.ep
%= asset 'app.css'
