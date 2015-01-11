package t::Helper;
use Mojo::Base -strict;
use Mojolicious;
use Test::Mojo;
use Test::More;
use Cwd ();

sub t {
  my ($class, $args) = @_;
  my $t = Test::Mojo->new(Mojolicious->new);

  $t->app->static->paths([Cwd::abs_path('t/public')]);
  $t->app->plugin(AssetPack => $args || {});
  $t->app->routes->get("/test1" => 'test1');
  $t;
}

sub import {
  my $class  = shift;
  my $caller = caller;

  plan skip_all => 'Not ready for alien host' unless $^O eq 'linux';

  unlink glob 't/public/packed/*';
  unlink glob 't/public/js/.*.cache';

  strict->import;
  warnings->import;

  eval <<"  CODE" or die $@;
  package $caller;
  use Test::More;
  use Test::Mojo;
  1;
  CODE
}

1;
