BEGIN { $ENV{MOJO_MODE} = 'not_development' }
use t::Helper;
use Mojo::Loader 'data_section';
use Mojolicious::Plugin::Assetpipe::Util 'checksum';

plan skip_all => 'cpanm CSS::Minifier::XS' unless eval 'require CSS::Minifier::XS;1';

my $t            = t::Helper->t;
my @assets       = qw( d/css-1-one.css d/css-1-two.css d/css-1-already-min.css );
my $url_checksum = checksum 'd/css-1-one.css';

$t->app->asset->process('app.css' => @assets);

my $file = $t->app->asset->store->file('processed/css-1-one-52be209045.min.css');
isa_ok($file, 'Mojo::Asset::File');

my $asset_checksum = checksum join ':',
  map { checksum(data_section __PACKAGE__, $_) } @assets;
$t->get_ok('/')->status_is(200)
  ->element_exists(qq(link[href="/asset/$asset_checksum/app.css"]));

$t->get_ok($t->tx->res->dom->at('link')->{href})->status_is(200)
  ->content_like(qr/\.one\{color.*\.two\{color.*.skipped\s\{/s);

Mojo::Util::monkey_patch('CSS::Minifier::XS', minify => sub { die 'Nope!' });
ok -e $file->path, 'cached file exists';
$ENV{MOJO_ASSETPIPE_CLEANUP} = 0;
$t = t::Helper->t;
$t->app->asset->process('app.css' => @assets);

$ENV{MOJO_ASSETPIPE_CLEANUP} = 1;
done_testing;

__DATA__
@@ index.html.ep
%= asset 'app.css'
@@ d/css-1-one.css
.one { color: #111; }
@@ d/css-1-two.css
.two { color: #222; }
@@ d/css-1-already-min.css
.skipped { color: #222; }
