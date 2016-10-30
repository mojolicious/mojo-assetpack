use t::Helper;

my $t = t::Helper->t(pipes => [qw(Css Combine)]);
$t->app->asset->process;

$t->get_ok('/')->status_is(200);
my $href = $t->tx->res->dom->at('link')->{href};
ok $href, 'found link[href]';

$t->get_ok($href => {Range => 'bytes=0-2'})->status_is(206)
  ->header_is('Accept-Ranges' => 'bytes')->content_is('.on');

done_testing;

__DATA__
@@ index.html.ep
%= asset 'app.css'
@@ assetpack.def
! app.css
< css-0-one.css
