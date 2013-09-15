use warnings;
use strict;
use Test::More;
use Test::Mojo;

plan skip_all => 'Not ready for alien host' unless $^O eq 'linux';

{
  package Embedded;
  use Mojolicious::Lite;
  plugin 'AssetPack' => { minify => 1, rebuild => 1 };

  app->asset->preprocessors->remove('js');
  app->asset->preprocessors->add(js => sub {
    my($assetpack, $text, $file) = @_;
    $$text = 'var too = "cool";';
  });
  app->asset('app.js' => '/js/a.js');
  get '/', sub { shift->render(text => 'Embedded') };
}

{
  package App;
  use Mojolicious::Lite;
  app->routes->route('/embed')->detour(app => Embedded::app);
  get '/', sub { shift->render(text => 'main') };
}

{
  my $t = Test::Mojo->new('Embedded');
  $t->get_ok("/packed/app.42.js")->status_is(200)->content_is('var too = "cool";');
}

{
  my $t = Test::Mojo->new('App');
  $t->get_ok("/")->status_is(200)->content_is('main');
  $t->get_ok("/embed")->status_is(200)->content_is('Embedded');
  $t->get_ok("/embed/packed/app.42.js")->status_is(200)->content_is('var too = "cool";');
}

done_testing;
