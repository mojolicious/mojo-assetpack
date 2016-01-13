BEGIN { $ENV{MOJO_MODE} = 'not_development' }
use t::Helper;
use Mojo::Loader 'data_section';
use Mojolicious::Plugin::Assetpipe::Util 'checksum';

plan skip_all => 'cpanm CSS::Minifier::XS' unless eval 'require CSS::Minifier::XS;1';

my $t            = t::Helper->t;
my @assets       = qw( d/one.css d/two.css d/already-min.css );
my $url_checksum = checksum 'd/one.css';

$t->app->asset->process('app.css' => @assets);

my $file = $t->app->asset->store->file('processed/one-ada9270f07.min.css');
ok $file, 'cache one';

my $asset_checksum = checksum join ':',
  map { checksum(data_section __PACKAGE__, $_) } @assets;
$t->get_ok('/')->status_is(200)
  ->element_exists(qq(link[href="/asset/$asset_checksum/app.css"]));

$t->get_ok($t->tx->res->dom->at('link')->{href})->status_is(200)
  ->content_like(qr/\.one\{color.*\.two\{color.*.skipped\s\{/s);

done_testing;

__DATA__
@@ index.html.ep
%= asset 'app.css'
@@ d/one.css
.one { color: #111; }
@@ d/two.css
.two { color: #222; }
@@ d/already-min.css
.skipped { color: #222; }
