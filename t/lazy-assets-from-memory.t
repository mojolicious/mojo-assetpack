use t::Helper;

diag 'build assets';
my $t1 = t::Helper->t({minify => 0});
$t1->app->asset('app.css' => '/css/a.css', '/css/b.css');

diag 'use existing assets';
my $t2 = Test::Mojo->new(Mojolicious->new);
my @log;

$t2->app->log->on(message => sub { push @log, $_[2] });
$t2->app->static->paths([]);    # force warning "AssetPack will store assets in memory" #56, commit after f4fb82a
$t2->app->plugin(AssetPack => {minify => 0});
$t2->app->static->paths($t1->app->static->paths);
$t2->app->asset('app.css' => '/css/a.css', '/css/b.css');
$t2->app->routes->get("/test1" => 'test1');

$t2->get_ok('/test1')->status_is(200);

is_deeply [grep {/store assets in memory/} @log], [], 'no "AssetPack will store assets in memory" message';

done_testing;

__DATA__
@@ test1.html.ep
%= asset 'app.css', {inline => 1}
