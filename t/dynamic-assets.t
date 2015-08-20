use Mojo::Base -base;
use Mojolicious::Lite;
use Test::Mojo;
use Test::More;
use t::Dynamic;

my $t = Test::Mojo->new(t::Dynamic->new);

$t->get_ok('/test.css')->status_is(200)->content_type_is('text/css')->content_is('body { background-color: blue }');
$t->get_ok('/inline')->status_is(200)->element_exists('style')->text_like('style', qr/body\{background-color:blue\}/);
$t->get_ok('/referred')->status_is(200)->text_like('html head style', qr/background-color:\s*blue/);

done_testing;
