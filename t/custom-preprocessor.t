use warnings;
use strict;
use Test::More;
use Test::Mojo;

plan skip_all => 'Not ready for alien host' unless $^O eq 'linux';
plan tests => 8;

{
  use Mojolicious::Lite;
  plugin 'AssetPack' => { minify => 1, rebuild => 1 };

  app->asset->preprocessors->remove('js');
  app->asset->preprocessors->add(js => sub {
    my($assetpack, $text, $file) = @_;
    $$text = 'var too = "cool";';
    like Cwd::getcwd, qr{public/js}, 'changed dir';
  });
  app->asset('app.js' => '/js/a.js');

  get '/js' => 'js';
}

my $t = Test::Mojo->new;

{
  $t->get_ok('/js'); # trigger pack_javascripts() twice for coverage
  $t->get_ok('/js')
    ->status_is(200)
    ->content_like(qr{<script src="/packed/app-09bd5aefd1b3f2697a79105d741a9116\.js".*}m)
    ;
  $t->get_ok("/packed/app-09bd5aefd1b3f2697a79105d741a9116.js")->status_is(200)->content_is('var too = "cool";');
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
