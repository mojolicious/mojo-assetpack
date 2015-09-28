package t::Helper;
use Mojo::Base -strict;
use Mojolicious;
use Test::Mojo;
use Test::More;
use Cwd ();
use File::Basename 'dirname';
use File::Spec;

sub t {
  my ($class, $args) = @_;
  my $static = delete $args->{static} || ['public'];
  my $t = Test::Mojo->new(Mojolicious->new(secrets => ['s3cret']));

  $args->{log} ||= [];
  $_ = Cwd::abs_path(File::Spec->catdir('t', $_)) for @$static;

  $t->app->home->parse(Cwd::abs_path(File::Spec->catdir(dirname $0)));
  $t->app->log->on(message => sub { push @{$args->{log}}, $_[2] });
  $t->app->log->on(message => sub { warn "[$_[1]] $_[2]\n" }) if $ENV{HARNESS_IS_VERBOSE};

  eval {
    $t->app->static->paths($static);
    $t->app->plugin(AssetPack => $args || {});
    my $out_dir = $t->app->asset->out_dir;
    die "Cannot write to out_dir=$out_dir\n" unless -w $out_dir;
    1;
  } or do {
    plan skip_all => $@;
  };

  $t->app->routes->get("/test1" => 'test1');
  $t;
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
