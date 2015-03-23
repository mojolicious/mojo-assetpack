use Mojo::Base -base;
use Mojolicious::Lite;
use Test::Mojo;
use Test::More;

my @READ_ONLY = qw( t/read-only-with-source-assets t/read-only-with-existing-assets );
my $t;

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

unlink $_ for glob $t->app->asset->out_dir . '/my-plugin*';
ok !-e $t->app->asset->out_dir . '/my-plugin-new-a81a17483efca304199a951e10068095.css', 'not yet generated asset';

$t->app->plugin('t::MyPlugin');
ok !-e "$READ_ONLY[0]/packed/my-plugin-existing-b764c538f579f2a774d88ae75f3a27de.css", $READ_ONLY[0];
ok !-e $t->app->asset->out_dir . '/my-plugin-new-b764c538f579f2a774d88ae75f3a27de.min.css', 'not yet generated asset';
ok -e $t->app->asset->out_dir . '/my-plugin-new-a81a17483efca304199a951e10068095.min.css',  'generated new asset';

$t->get_ok('/test1')->status_is(200)->text_like('style', qr/body\{color:\#aaa\}body\{color:\#aaa\}/);

chmod 0775, $_ for @READ_ONLY;
done_testing;

__DATA__
@@ test1.html.ep
%= asset 'my-plugin-existing.css', { inline => 1 }
%= asset 'my-plugin-new.css', { inline => 1 }
