use lib '.';
use t::Helper;

$ENV{MOJO_MODE} = 'development';
my $t = t::Helper->t(pipes => [qw(Css)]);
$t->app->asset->process;

$t->app->asset->route->to(base_url => '//cdn.example.com/my-assets/');
$t->get_ok('/')->status_is(200)
  ->content_like(qr{="//cdn.example.com/my-assets/asset/ec4c05a328/css-0-two.css"});

done_testing;

__DATA__
@@ index.html.ep
%= asset 'app.css'
@@ assetpack.def
! app.css
< css-0-two.css
@@ css-0-one.css
.one { color: #000; }
