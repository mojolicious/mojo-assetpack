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
  plugin 'AssetPack' => { minify => 1, url_prefix => $url_prefix };

  app->asset('app.js' => '/js/a.js', '/js/b.js');
  app->asset('app.css' => '/css/c.css', '/css/d.css');
  $assetpack = app->asset;

  get '/js' => 'js';
  get '/css' => 'css';
}

my $t = Test::Mojo->new;

{
  $t->get_ok('/js'); # trigger pack_javascripts() twice for coverage
  $t->get_ok('/js')
    ->status_is(200)
    ->content_like(qr{<script src="$url_prefix/packed/app-8072d187db8ff7a1809b88ae1a5f3bd7\.js".*}m)
    ;
}

{
  $t->get_ok('/css')
    ->status_is(200)
    ->content_like(qr{<link href="http://static.app.com/packed/app-9113e4a5ae6bad4b3c8343549984ae3d\.css".*}m)
    ;
}

__DATA__
@@ js.html.ep
%= asset 'app.js'
@@ css.html.ep
%= asset 'app.css'
