package t::Helper;
use Mojo::Base -strict;
use Mojo::Loader;
use Mojolicious;
use Mojolicious::Plugin::AssetPack::Util;
use Cwd ();
use File::Basename qw(basename dirname);
use File::Spec;
use Test::Mojo;
use Test::More;

$ENV{MOJO_LOG_LEVEL} = $ENV{HARNESS_IS_VERBOSE} ? 'debug' : 'error';

sub t {
  my $class = shift;
  my $args  = ref $_[0] ? shift : {@_};
  my $app   = Mojolicious->new;

  $ENV{MOJO_ASSETPACK_CLEANUP} //= 1;    # remove generated assets
  $ENV{MOJO_ASSETPACK_DB_FILE} = sprintf '%s.db', basename $0;
  ${$app->home} = Cwd::abs_path(dirname __FILE__);
  delete $app->log->{$_} for qw(handle path);
  $app->routes->get('/' => 'index');
  $app->plugin(AssetPack => $args);
  return Test::Mojo->new($app);
}

sub import {
  my $class  = shift;
  my $caller = caller;

  unlink glob 't/public/packed/*' unless $ENV{TEST_KEEP_FILES};

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
