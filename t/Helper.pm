package t::Helper;
use Mojo::Base -strict;

use Mojo::File 'path';
use Mojo::Util;
use Mojo::Loader;
use Mojolicious::Plugin::AssetPack::Util;
use Mojolicious;
use Test::Mojo;
use Test::More ();

$ENV{MOJO_LOG_LEVEL} = $ENV{HARNESS_IS_VERBOSE} ? 'debug' : 'error';
$ENV{TEST_HOME}      = path(__FILE__)->to_abs->dirname;

END { cleanup() }

my %CREATED_FILES;

unless ($ENV{TEST_KEEP_FILES}) {
  my $spew = \&Mojo::File::spew;
  Mojo::Util::monkey_patch(
    'Mojo::File' => spew => sub {
      $CREATED_FILES{$_[0]} = 1 unless -e $_[0];
      goto $spew;
    }
  );
}

sub cleanup {
  $CREATED_FILES{path($ENV{TEST_HOME}, 'assets', $ENV{MOJO_ASSETPACK_DB_FILE})} = 1
    if $ENV{MOJO_ASSETPACK_DB_FILE} and !$ENV{TEST_KEEP_FILES};
  unlink $_ for keys %CREATED_FILES;
}

sub t {
  my $class = shift;
  my $args  = ref $_[0] ? shift : {@_};
  my $app   = Mojolicious->new;

  $ENV{MOJO_ASSETPACK_DB_FILE} = sprintf '%s.db', path($0)->basename;
  $class->cleanup unless state $cleaned_up++;
  ${$app->home} = $ENV{TEST_HOME};
  delete $app->log->{$_} for qw(handle path);
  $app->routes->get('/' => 'index');
  $app->plugin(AssetPack => $args);
  return Test::Mojo->new($app);
}

sub import {
  my $class  = shift;
  my $caller = caller;

  Mojo::Base->import('-strict');

  eval <<"HERE" or die $@;
  package $caller;
  use Test::More;
  use Test::Mojo;
  1;
HERE
}

1;
