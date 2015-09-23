use t::Helper;
use File::Spec::Functions 'catdir';

# existing file
my $t = t::Helper->t({minify => 1, fallback_to_latest => 1, static => ['read-only-with-existing-assets']});
$t->app->asset('my-plugin-existing.css' => 'force-fallback-not-existing-asset.css');
$t->get_ok('/test1')->status_is(200)->content_like(qr/body\{color:\#aaa\}body\{color:\#aaa\}/);
$t->get_ok($t->tx->res->dom->at('link')->{href})->status_is(200);

# later version
my $latest = $t->app->asset->_asset("packed/my-plugin-existing-11111111111111111111111111111111.css")
  ->spurt('/* latest-version-42 */');
$t = t::Helper->t({minify => 1, fallback_to_latest => 1, static => ['read-only-with-existing-assets']});
$t->app->asset('my-plugin-existing.css' => 'force-fallback-not-existing-asset.css');
$t->get_ok('/test1')->status_is(200)->content_like(qr/latest-version-42/);
unlink $latest->path;

done_testing;
__DATA__
@@ test1.html.ep
%= asset 'my-plugin-existing.css', { inline => 1 }
%= asset 'my-plugin-existing.css';
