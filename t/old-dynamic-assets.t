use t::Helper;
use t::Dynamic;
use Mojolicious::Plugin::AssetPack;
use Mojolicious::Lite;

plan skip_all => 'TEST_OLD=1' unless $ENV{TEST_OLD};

my $t = Test::Mojo->new(t::Dynamic->new);

$t->get_ok('/test.css')->status_is(200)->content_type_is('text/css')
  ->content_is('body { background-color: blue }');
$t->get_ok('/inline')->status_is(200)->element_exists('style')
  ->text_like('style', qr/body\{background-color:blue\}/);
$t->get_ok('/referred')->status_is(200)
  ->text_like('html head style', qr/background-color:\s*blue/);

done_testing;
