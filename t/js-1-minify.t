BEGIN { $ENV{MOJO_MODE} = 'not_development' }
use Mojo::Base -strict;
use Mojo::Loader 'data_section';
use Mojolicious::Lite;
use Mojolicious::Plugin::Assetpipe::Util 'checksum';
use Test::Mojo;
use Test::More;

get '/' => 'index';
plugin 'assetpipe';
app->asset->process('app.js' => ('d/one.js', 'd/two.js'));

my $t        = Test::Mojo->new;
my $checksum = checksum join ':',
  map { checksum(data_section __PACKAGE__, $_) } 'd/one.js', 'd/two.js';

$t->get_ok('/')->status_is(200)
  ->element_exists(qq(script[src="/asset/$checksum/app.js"]));

$t->get_ok("/asset/$checksum/app.js")->status_is(200)
  ->content_like(qr/function\(\)\{console/s);

done_testing;

__DATA__
@@ index.html.ep
%= asset 'app.js'
@@ d/one.js
(function() { console.log('one') })();
@@ d/two.js
(function() { console.log('two') })();
