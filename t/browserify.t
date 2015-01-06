use t::Helper;

plan skip_all => 'npm install browserify' unless -d 'node_modules/browserify';

my $t = t::Helper->t({});

$t->app->asset->preprocessor(
  Browserify => {
    environment => 'development',
    extensions  => [qw( js jsx )],    # default is "js"
  },
);

$t->app->asset('app.js'    => '/js/boop.js');
$t->app->asset('parent.js' => '/js/ctrl.js');

$t->get_ok('/test1')->status_is(200)->content_like(qr{s\.toUpperCase\(.*'\!'}, 'robot.js')
  ->content_like(qr{console\.log\(robot\('boop'\)\);}, 'boop.js');

done_testing;

__DATA__
@@ test1.html.ep
%= asset "app.js" => {inline => 1}
%= asset "parent.js" => {inline => 1}
