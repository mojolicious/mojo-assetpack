use lib '.';
use t::Helper;
use Mojo::Loader 'data_section';
use Mojolicious::Plugin::AssetPack::Util 'checksum';

plan skip_all => 'cpanm CSS::Minifier::XS' unless eval 'require CSS::Minifier::XS;1';

my $t = t::Helper->t(pipes => [qw(Css Combine)]);
$t->app->asset->process;
$t->get_ok('/')->status_is(200)->element_exists(qq(link[href="/asset/d508287fc7/css-0-one.css"]))
  ->element_exists(qq(link[href="/asset/ec4c05a328/css-0-two.css"]));

$t->get_ok($t->tx->res->dom->at('link')->{href})->status_is(200)->content_like(qr{aaa});

$ENV{MOJO_MODE} = 'test_minify_from_here';
my @assets       = qw(d/x.css d/y.css d/already-min.css);
my $url_checksum = checksum 'd/x.css';

$t = t::Helper->t(pipes => [qw(Css Combine)]);
$t->app->asset->process('app.css' => @assets);
my $file = $t->app->asset->store->file('cache/x-026c9c3a29.min.css');
isa_ok($file, 'Mojo::Asset::File');
ok -e $file->path, 'cached file exists';

Mojo::Util::monkey_patch('CSS::Minifier::XS', minify => sub { die 'Not cached!' });
$t = t::Helper->t(pipes => [qw(Css Combine)]);
$t->app->asset->process('app.css' => @assets);

$t->app->routes->get('/inline' => 'inline');
$t->get_ok('/inline')->status_is(200)->content_like(qr/\.one\{color.*\.two\{color.*.skipped\s\{/s);

$t->app->asset->process('app.css' => @assets);

my $asset_checksum = checksum join ':', map { checksum(data_section __PACKAGE__, $_) } @assets;
$t->get_ok('/')->status_is(200)->element_exists(qq(link[href="/asset/$asset_checksum/app.css"]));

$t->get_ok($t->tx->res->dom->at('link')->{href})->status_is(200)->header_is('Cache-Control', 'max-age=31536000')
  ->header_is('Content-Type', 'text/css')->content_like(qr/\.one\{color.*\.two\{color.*.skipped\s\{/s);

done_testing;

__DATA__
@@ index.html.ep
%= asset 'app.css'
@@ inline.html.ep
%= stylesheet sub { asset->processed('app.css')->map('content')->join }
@@ assetpack.def
! app.css
# some comment
< css-0-one.css       #some inline comment
<   css-0-two.css # other comment
@@ d/x.css
.one { color: #111; }
@@ d/y.css
.two { color: #222; }
@@ d/already-min.css
.skipped { color: #222; }
