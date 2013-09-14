use warnings;
use strict;
use Test::More;
use Test::Mojo;

plan skip_all => 'Not ready for alien host' unless $^O eq 'linux';

{
  use Mojolicious::Lite;
  plugin 'AssetPack' => { enable => 1, reset => 1 };
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
    ->content_like(qr{<script src="/packed/\w+\.js".*}m)
    ;
}

if($Mojolicious::Plugin::AssetPack::APPLICATIONS{less}) {
  $t->get_ok('/less'); # trigger pack_stylesheets() twice for coverage
  $t->get_ok('/less')
    ->status_is(200)
    ->content_like(qr{<link href="/packed/\w+\.css".*}m)
    ;
}

if($Mojolicious::Plugin::AssetPack::APPLICATIONS{scss}) {
  $t->get_ok('/sass')
    ->status_is(200)
    ->content_like(qr{<link href="/packed/\w+\.css".*}m)
    ;
}

{
  $t->get_ok('/css')
    ->status_is(200)
    ->content_like(qr{<link href="/packed/\w+\.css".*}m)
    ;
}

done_testing;
__DATA__
@@ js.html.ep
%= asset '/js/a.js', '/js/b.js'
@@ less.html.ep
%= asset '/css/a.less', '/css/b.less'
@@ sass.html.ep
%= asset '/css/a.scss', '/css/b.scss'
@@ css.html.ep
%= asset '/css/c.css', '/css/d.css'
