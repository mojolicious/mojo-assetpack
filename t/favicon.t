use lib '.';
use File::Basename 'basename';
use t::Helper;

plan skip_all => 'TEST_REALFAVICONGENERATOR_API_KEY=is_not_set' unless $ENV{TEST_REALFAVICONGENERATOR_API_KEY};

my $t = t::Helper->t(pipes => [qw(Favicon)]);
my %sub_asset;

$t->app->asset->pipe('Favicon')->api_key($ENV{TEST_REALFAVICONGENERATOR_API_KEY});
$t->app->asset->process('favicon.ico' => '/image/master_favicon_thumbnail.png');

$t->get_ok('/')->status_is(200)->element_exists('[href$="114x114.png"][rel="apple-touch-icon"][sizes="114x114"]')
  ->element_exists('[href$="120x120.png"][rel="apple-touch-icon"][sizes="120x120"]')
  ->element_exists('[href$="57x57.png"][rel="apple-touch-icon"][sizes="57x57"]')
  ->element_exists('[href$="60x60.png"][rel="apple-touch-icon"][sizes="60x60"]')
  ->element_exists('[href$="72x72.png"][rel="apple-touch-icon"][sizes="72x72"]')
  ->element_exists('[href$="76x76.png"][rel="apple-touch-icon"][sizes="76x76"]')
  ->element_exists('[href$="16x16.png"][rel="icon"][sizes="16x16"][type="image/png"]')
  ->element_exists('[href$="32x32.png"][rel="icon"][sizes="32x32"][type="image/png"]')
  ->element_exists('[href$="safari-pinned-tab.svg"][color="#536DFE"][rel="mask-icon"]')
  ->element_exists('[href$="site.webmanifest"][rel="manifest"]')
  ->element_exists('[name="msapplication-config"][content$="browserconfig.xml"]')
  ->element_exists('[name="msapplication-TileColor"][content="#536DFE"]')
  ->element_exists('[name="theme-color"][content="#536DFE"]');

# Make sure that all the [href] above looks like /asset/19b5e7c873/apple-touch-icon-57x57.png
$t->tx->res->dom->find("[href], [content]")->each(sub {
  my $src = $_->{href} || $_->{content};
  return if $src =~ m!\#!;    # Skip content="#536DFE"
  my $name = basename $src;
  $sub_asset{$name} = $src;
  like $src, qr{^/asset/\w+/\w+.*$}, "meta $src";
});

$t->get_ok($sub_asset{'site.webmanifest'})->status_is(200)->json_like('/icons/0/src', qr{^/asset/\w+/[\w-]+\.png$})
  ->json_like('/icons/1/src', qr{^/asset/\w+/[\w-]+\.png$});

$t->get_ok($sub_asset{'browserconfig.xml'})->status_is(200);
like $t->tx->res->dom->at('square150x150logo[src]')->{src}, qr{^/asset/\w+/mstile-150x150.png},
  'browserconfig.xml square150x150logo';

#$t->get_ok($sub_asset{'manifest.webapp'})->content_is(1);

{
  no warnings 'redefine';
  local *Mojolicious::Plugin::AssetPack::Pipe::Favicon::_request = sub { die $_[1] };
  eval { $t->app->asset->process('favicon.cool_beans.ico' => '/image/sample.png') };
  like "$@", qr{Mojolicious::Plugin::AssetPack::Asset}, 'will also process variants of the favicon';
}

done_testing;

__DATA__
@@ index.html.ep
favicon!
%= asset 'favicon.ico'
