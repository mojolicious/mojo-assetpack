use lib '.';
use t::Helper;

plan skip_all => 'TEST_REALFAVICONGENERATOR_API_KEY=is_not_set'
  unless $ENV{TEST_REALFAVICONGENERATOR_API_KEY};

my $t = t::Helper->t(pipes => [qw(Favicon)]);
$t->app->asset->pipe('Favicon')->api_key($ENV{TEST_REALFAVICONGENERATOR_API_KEY});
$t->app->asset->process('favicon.ico' => '/image/master_favicon_thumbnail.png');
$t->get_ok('/')->status_is(200)
  ->element_exists('[href$="114x114.png"][rel="apple-touch-icon"][sizes="114x114"]')
  ->element_exists('[href$="120x120.png"][rel="apple-touch-icon"][sizes="120x120"]')
  ->element_exists('[href$="57x57.png"][rel="apple-touch-icon"][sizes="57x57"]')
  ->element_exists('[href$="60x60.png"][rel="apple-touch-icon"][sizes="60x60"]')
  ->element_exists('[href$="72x72.png"][rel="apple-touch-icon"][sizes="72x72"]')
  ->element_exists('[href$="76x76.png"][rel="apple-touch-icon"][sizes="76x76"]')
  ->element_exists('[href$="16x16.png"][rel="icon"][sizes="16x16"][type="image/png"]')
  ->element_exists('[href$="32x32.png"][rel="icon"][sizes="32x32"][type="image/png"]')
  ->element_exists('[href$="safari-pinned-tab.svg"][color="#536DFE"][rel="mask-icon"]')
  ->element_exists('[href$="site.webmanifest"][rel="manifest"]')
  ->element_exists('[name="msapplication-TileColor"][content="#536DFE"]')
  ->element_exists('[name="theme-color"][content="#536DFE"]');

# Make sure that all the [href] above looks like /asset/19b5e7c873/apple-touch-icon-57x57.png
$t->tx->res->dom->find("[href]")->each(
  sub {
    like $_->{href}, qr{^/asset/\w+/\w+.*$}, "href $_->{href}";
  }
);

done_testing;

__DATA__
@@ index.html.ep
favicon!
%= asset 'favicon.ico'
