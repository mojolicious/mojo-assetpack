use warnings;
use strict;
use Test::More;

plan skip_all => 'CONCURRENT=1 prove t/concurrent.t' unless $ENV{CONCURRENT};

#
# I have no idea how to make this into a proper unittest.
# The idea is to see that only one child asset the files.
#

my @pid;

{
  use Mojolicious::Lite;
  plugin 'AssetPack' => { enable => 1, reset => 1 };
  app->secret($$);
  get '/js' => 'js';
  push @pid, fork;
  $pid[0] or app->start('daemon', '--listen' => 'http://*:6000');
  push @pid, fork;
  $pid[1] or app->start('daemon', '--listen' => 'http://*:6001');
}

my $ua = Mojo::UserAgent->new;

{
  my $delay = Mojo::IOLoop->delay;
  $ua->get('http://localhost:6000/js', $delay->begin);
  $ua->get('http://localhost:6001/js', $delay->begin);
  $delay->wait;
  ok 1, 'no idea how to test this';
}

kill 15, $_ for @pid;
wait;

done_testing;
__DATA__
@@ js.html.ep
%= asset '/js/a.js', '/js/already.min.js'
