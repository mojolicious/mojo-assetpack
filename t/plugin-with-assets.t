use Mojo::Base -base;
use Mojolicious::Lite;
use Test::Mojo;
use Test::More;

my @READ_ONLY = qw( t/read-only-with-source-assets t/read-only-with-existing-assets );
my ($assetpack, $t);

{
  unlink $_ for glob "$READ_ONLY[0]/packed/my-plugin-*.css";
  mkdir $_  for @READ_ONLY;
  chmod 0555, $_ for @READ_ONLY;
  plan skip_all => 'Need unix filesystem' unless 0555 == (0777 & (stat $READ_ONLY[0])[2]);
}

$t = Test::Mojo->new;
$t->app->mode('production');
$t->app->routes->get('/test1' => 'test1');
$t->app->static->paths([@READ_ONLY]);
$t->app->plugin('AssetPack');

$assetpack = $t->app->asset;
is $assetpack->out_dir, '', 'in_memory assets';

$t->app->plugin('t::SomePluginWithAssets');
is $t->app->asset, $assetpack, 'same assetpack';

$t->get_ok('/test1')->status_is(200)->content_like(qr/body\{color:\#aaa\}body\{color:\#aaa\}/)
  ->content_like(qr/body\{color:\#bbb\}body\{color:\#bbb\}/);

my @href = $t->tx->res->dom->find('link')->map(sub { $_->{href} })->each;
my @names = map { File::Basename::basename($_) } @href;

is_deeply(
  [@names],
  ['my-plugin-existing-7c174b801d6fc968f1576055e88c18cb.css', 'my-plugin-new-a81a17483efca304199a951e10068095.min.css'],
  'got assets'
);

is $assetpack->_asset($names[0])->in_memory, 0, 'existing is bundled with t::SomePluginWithAssets';
like $assetpack->_asset($names[0])->url, qr{t/read-only-with-existing-assets$href[0]$}, 'and stored in memory';
$t->get_ok($href[0])->status_is(200)->content_like(qr{color:\#aaa});

is $assetpack->_asset($names[1])->in_memory, 1,            'new is regerated now and stored in memory';
is $assetpack->_asset($names[1])->url,       "/$names[1]", 'and has a virtual url';
$t->get_ok($href[1])->status_is(200)->content_like(qr{color:\#bbb});

chmod 0775, $_ for @READ_ONLY;
done_testing;

__DATA__
@@ test1.html.ep
%= asset 'my-plugin-existing.css', { inline => 1 }
%= asset 'my-plugin-new.css', { inline => 1 }
%= asset 'my-plugin-existing.css'
%= asset 'my-plugin-new.css'
