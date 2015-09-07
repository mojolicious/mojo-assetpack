use t::Helper;

my $args      = {minify => 0, out_dir => '', headers => {'Cache-Control' => 'max-age=31536000'}};
my $t         = t::Helper->t($args);
my $assetpack = $t->app->asset;

$t->app->asset('in-memory.css' => '/from-data.css');

$t->get_ok('/test1')->status_is(200)->text_like('style', qr/background:#123;/)
  ->element_exists('link[href="/packed/from-data-f580ad0fd8d617446dda2a00e75cf8c2.css"]');

$t->get_ok('/packed/from-data-f580ad0fd8d617446dda2a00e75cf8c2.css')->content_like(qr/background:#123;/)
  ->header_is('Cache-Control', 'max-age=31536000');

ok !-e File::Spec->catfile(qw( t public packed from-data-f580ad0fd8d617446dda2a00e75cf8c2.css )),
  'no file was created on disk';

ok $t->app->asset->{assets_from_memory}, 'AssetPack will serve assets from memory';

$t->get_ok('/packed/../../00-basic.t')->status_is(404)->header_is('Cache-Control', undef);

done_testing;

__DATA__
@@ from-data.css
body{background:#123;}
@@ test1.html.ep
%= asset 'in-memory.css', {inline => 1}
%= asset 'in-memory.css'
