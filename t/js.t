BEGIN { $ENV{MOJO_MODE} = 'not_development' }
use lib '.';
use t::Helper;
use Mojo::Loader 'data_section';
use Mojolicious::Plugin::AssetPack::Util 'checksum';

plan skip_all => 'cpanm JavaScript::Minifier::XS'
  unless eval 'require JavaScript::Minifier::XS;1';

my $t = t::Helper->t(pipes => [qw(JavaScript Combine)]);
my $checksum = checksum join ':',
  map { checksum(data_section __PACKAGE__, $_) } 'd/one.js', 'd/two.js';

$t->app->asset->process('app.js' => ('d/one.js', 'd/two.js'));

$t->get_ok('/')->status_is(200)
  ->element_exists(qq(script[src="/asset/$checksum/app.js"]));

$t->get_ok($t->tx->res->dom->at('script')->{src})->status_is(200)
  ->header_is('Content-Type', 'application/javascript')
  ->content_like(qr/function\(\)\{console/s);

done_testing;

__DATA__
@@ index.html.ep
%= asset 'app.js'
@@ d/one.js
(function() { console.log('one') })();
@@ d/two.js
(function() { console.log('two') })();
