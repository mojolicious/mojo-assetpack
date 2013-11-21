use warnings;
use strict;
use Test::More;
use Test::Mojo;

plan skip_all => 'Not ready for alien host' unless $^O eq 'linux';
plan tests => 8;

unlink glob 't/public/packed/*';

{
  use Mojolicious::Lite;
  plugin 'AssetPack' => { minify => 1 };

  my $cwd = 'UNDEFINED';
  app->asset->preprocessors->remove('js');
  app->asset->preprocessors->add(js => sub {
    my($assetpack, $text, $file) = @_;
    $$text = 'var too = "cool";';
    $cwd = Cwd::getcwd;
  });

  app->asset('app.js' => '/js/a.js');

  get '/js' => 'js';
  like $cwd, qr{public/js}, 'changed dir';
}

my $t = Test::Mojo->new;

{
  $t->get_ok('/js'); # trigger pack_javascripts() twice for coverage
  $t->get_ok('/js')
    ->status_is(200)
    ->content_like(qr{<script src="/packed/app-527b09c38362b669ec6e16c00d9fb30d\.js".*}m)
    ;

  $t->get_ok($t->tx->res->dom->at('script')->{src})
    ->status_is(200)
    ->content_is('var too = "cool";')
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
