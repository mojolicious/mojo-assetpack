BEGIN { $ENV{MOJO_MODE} = 'not_development' }
use Mojo::Base -strict;
use Mojo::Loader 'data_section';
use Mojolicious::Lite;
use Mojolicious::Plugin::Assetpipe::Util 'checksum';
use Test::Mojo;
use Test::More;

get '/' => 'index';
plugin 'assetpipe';
app->asset->process('app.css' => ('d/one.css', 'd/two.css'));

my $t        = Test::Mojo->new;
my $checksum = checksum join ':',
  map { checksum(data_section __PACKAGE__, $_) } 'd/one.css', 'd/two.css';

$t->get_ok('/')->status_is(200)
  ->element_exists(qq(link[href="/asset/$checksum/app.css"]));

$t->get_ok("/asset/$checksum/app.css")->status_is(200)
  ->content_like(qr/\.one\{color.*\.two\{color/s);

done_testing;

__DATA__
@@ index.html.ep
%= asset 'app.css'
@@ d/one.css
.one { color: #111; }
@@ d/two.css
.two { color: #222; }
