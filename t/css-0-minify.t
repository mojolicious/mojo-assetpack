use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use Mojolicious::Lite;

get '/' => 'index';
plugin 'assetpipe';
app->asset->process('app.css' => ('/one.css', '/two.css'));

my $t = Test::Mojo->new;
$t->get_ok('/')->status_is(200)
  ->element_exists(qq(link[href="/asset/d508287fc7/one.css"]))
  ->element_exists(qq(link[href="/asset/ec4c05a328/two.css"]));

done_testing;

__DATA__
@@ index.html.ep
%= asset 'app.css'
