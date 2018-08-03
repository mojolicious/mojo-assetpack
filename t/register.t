use lib '.';
use t::Helper;

$ENV{HTTP_PROXY} = 'example.com';
$ENV{NO_PROXY}   = 'mojolicious.org';
$ENV{no_proxy}   = '';

ok !eval '$undeclared_variable=123', 'strict is enabled';

my $t = Test::Mojo->new(Mojolicious->new);
delete $t->app->log->{$_} for qw(path handle);
$t->app->plugin(AssetPack => {helper => 'foo', pipes => ['Css']});
isa_ok $t->app->foo, 'Mojolicious::Plugin::AssetPack';
is $t->app->foo->ua->server->app, $t->app, 'app';
is $t->app->foo->ua->proxy->http, 'example.com', 'proxy http';

$t->app->foo->process('x.css' => 'a.css');
$t->get_ok('/asset/e270d1889a/a.css')->status_is(200)->content_like(qr{aaa});

{
  local $TODO = $^O eq 'MSWin32' ? 'Proxy test fail on windows' : undef;
  is_deeply $t->app->foo->ua->proxy->not, [qw(mojolicious.org 127.0.0.1 ::1 localhost)], 'proxy not';
}

$t = Test::Mojo->new(Mojolicious->new);
$t->app->plugin(AssetPack => {pipes => ['Css'], proxy => 0});
ok !$t->app->asset->ua->proxy->http, 'no http proxy';

$t = Test::Mojo->new(Mojolicious->new);
$t->app->plugin(AssetPack => {pipes => ['Css']});
is @{$t->app->asset->{pipes}}, 1, 'only one pipe';

eval { $t->app->asset->process('test.css' => '/file/not/found.css') };
like $@, qr{Could not find input asset}, 'file not found';

done_testing;
__DATA__
@@ a.css
.one { color: #aaa; }
