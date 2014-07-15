package t::Helper;
use Mojo::Base -strict;
use Mojolicious;
use Test::Mojo;
use Test::More;

sub t {
  my ($class, $args) = @_;
  my $t = Test::Mojo->new(Mojolicious->new);
  my $route = $0;

  $route =~ s!\.t!!;
  $route =~ s!.*/!!;

  diag "Add route /$route";

  $t->app->static->paths([ 't/public' ]);
  $t->app->plugin(AssetPack => $args || {});
  $t->app->routes->get("/$route" => $route);
  $t;
}

sub import {
  my $class = shift;
  my $caller = caller;

  plan skip_all => 'Not ready for alien host' unless $^O eq 'linux';

  unlink glob 't/public/packed/*';

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
