use Mojo::Base -strict;
use Mojolicious;
use Test::Mojo;
use Test::More;

$ENV{HTTP_PROXY} = 'example.com';
$ENV{NO_PROXY}   = 'mojolicious.org';
$ENV{no_proxy}   = '';

my $t = Test::Mojo->new(Mojolicious->new);
$t->app->plugin(AssetPack => {helper => 'foo', pipes => ['Css']});
isa_ok $t->app->foo, 'Mojolicious::Plugin::AssetPack';
is $t->app->foo->ua->server->app, $t->app, 'app';
is $t->app->foo->ua->proxy->http, 'example.com', 'proxy http';

{
  local $TODO = $^O eq 'Win32' ? 'Proxy test fail on windows' : undef;
  is_deeply $t->app->foo->ua->proxy->not, [qw(mojolicious.org 127.0.0.1 ::1 localhost)],
    'proxy not';
}

$t = Test::Mojo->new(Mojolicious->new);
$t->app->plugin(AssetPack => {pipes => ['Css'], proxy => 0});
ok !$t->app->asset->ua->proxy->http, 'no http proxy';

$t = Test::Mojo->new(Mojolicious->new);
$t->app->plugin(AssetPack => {pipes => ['Css']});
is @{$t->app->asset->{pipes}}, 1, 'only one pipe';

done_testing;
