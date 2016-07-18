use t::Helper;

plan skip_all => 'TEST_REALFAVICONGENERATOR_API_KEY=is_not_set'
  unless $ENV{TEST_REALFAVICONGENERATOR_API_KEY};

my $t = t::Helper->t(pipes => [qw(Favicon)]);
$t->app->asset->pipe('Favicon')->api_key($ENV{TEST_REALFAVICONGENERATOR_API_KEY});
$t->app->asset->process('favicon.ico' => '/image/master_favicon_thumbnail.png');
$t->get_ok('/')->status_is(200)->element_exists('[sizes="16x16"]')
  ->element_exists('[sizes="32x32"]');

like $t->tx->res->dom->at('[rel="shortcut icon"]')->{href}, qr{/favicon\.ico$},
  'plain favicon';
$t->get_ok($t->tx->res->dom->at('[sizes="16x16"]')->{href})->status_is(200);

done_testing;

__DATA__
@@ index.html.ep
favicon!
%= asset 'favicon.ico'
