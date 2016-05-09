use t::Helper;

# This part does not required optipng
my $t = t::Helper->t(pipes => [qw(Jpeg Combine)]);
$t->app->asset->process('test.jpeg' => '/image/photo-1429734160945-4f85244d6a5a.jpg');
$t->get_ok('/')->status_is(200)
  ->element_exists(qq(img[src="/asset/99cc392264/photo-1429734160945-4f85244d6a5a.jpg"]));
$t->get_ok($t->tx->res->dom->at('img')->{src})->status_is(200)
  ->header_is('Content-Type' => 'image/jpeg');

my $len = $t->tx->res->headers->content_length;
diag "original size: $len";

if ($ENV{TEST_JPEG} or -e '.test-everything') {
  $ENV{MOJO_MODE} = 'production';
  $t = t::Helper->t(pipes => [qw(Jpeg Combine)]);
  $t->app->asset->process('test.jpeg' => '/image/photo-1429734160945-4f85244d6a5a.jpg');
  $t->get_ok('/')->status_is(200)
    ->element_exists(
    qq(img[src="/asset/99cc392264/photo-1429734160945-4f85244d6a5a.jpg"]));
  $t->get_ok($t->tx->res->dom->at('img')->{src})->status_is(200)
    ->header_is('Content-Type' => 'image/jpeg')->header_isnt('Content-Length' => $len);
  my $len2 = $t->tx->res->headers->content_length;
  diag "jpegoptim size: $len2";
}

done_testing;

__DATA__
@@ index.html.ep
cool image!
%= asset 'test.jpeg'
