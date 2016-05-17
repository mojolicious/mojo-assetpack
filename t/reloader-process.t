use t::Helper;
plan skip_all => 'cpanm CSS::Sass' unless eval 'use CSS::Sass 3.3.0;1';

my $file = Mojo::Asset::File->new(path => 't/assets/t-reloader.scss');
eval { $file->add_chunk("body{color:#000;}\n") }
  or plan skip_all => "t-reloader.scss: $!";

my $t = t::Helper->t(pipes => [qw(Sass Combine Reloader)]);
my $asset = $t->app->asset->store->asset('t-reloader.scss');
$t->app->asset->process('app.css' => $asset);

$t->websocket_ok('/mojo-assetpack-reloader-ws');
Mojo::IOLoop->one_tick;
is $t->app->asset->processed('app.css')->first->checksum, 'c42b4ed75e',
  'initial checksum';

$file->add_chunk("div{color:#fff;}\n");
$t->finished_ok(1005);

is $t->app->asset->processed('app.css')->first->checksum, 'ee9b1ee297',
  'checksum after chunk added';

unlink $file->path;

done_testing;
__DATA__
@@ index.html.ep
%= asset 'app.css'
%= asset 'reloader.js'
