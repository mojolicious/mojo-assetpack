use lib '.';
use t::Helper;

# This part does not required optipng
my $t = t::Helper->t(pipes => [qw(Png Combine)]);
$t->app->asset->process('test.png' => '/image/sample.png');
$t->get_ok('/')->status_is(200)
  ->element_exists(qq(img[src="/asset/348b799a81/sample.png"]));
$t->get_ok($t->tx->res->dom->at('img')->{src})->status_is(200)
  ->header_is('Content-Type' => 'image/png');

my $len = $t->tx->res->headers->content_length;
diag "original size: $len";

if ($ENV{TEST_PNG}) {
  $ENV{MOJO_MODE} = 'production';

  for my $app (qw(pngquant optipng)) {
    $t = t::Helper->t(pipes => [qw(Png Combine)]);
    $t->app->asset->pipe('Png')->app($app);
    $t->app->asset->process('test.png' => '/image/sample.png');
    $t->get_ok('/')->status_is(200)
      ->element_exists(qq(img[src="/asset/348b799a81/sample.png"]));
    $t->get_ok($t->tx->res->dom->at('img')->{src})->status_is(200)
      ->header_is('Content-Type' => 'image/png')->header_isnt('Content-Length' => $len);
    my $len2 = $t->tx->res->headers->content_length;
    diag "$app size: $len2";
  }
}

done_testing;

__DATA__
@@ index.html.ep
cool image!
%= asset 'test.png'
