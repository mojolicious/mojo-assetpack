use t::Helper;

my %expected_element = (
  gif  => q(img[src="/asset/d220f096b3/dummy.gif"]),
  ico  => q(link[rel="icon"][href="/asset/40c24538f4/dummy.ico"]),
  mp3  => q(source[type="audio/mpeg"][src="/asset/1710ca7e28/dummy.mp3"]),
  mp4  => q(source[type="video/mp4"][src="/asset/228088807c/dummy.mp4"]),
  ogg  => q(source[type="audio/ogg"][src="/asset/641f8d27ad/dummy.ogg"]),
  ogv  => q(source[type="video/ogg"][src="/asset/cbfe0298bd/dummy.ogv"]),
  svg  => q(img[src="/asset/64705cb07d/dummy.svg"]),
  webm => q(source[type="video/webm"][src="/asset/fc19b68890/dummy.webm"]),
);

my $t = t::Helper->t(pipes => ['Combine']);

for my $ext (sort keys %expected_element) {
  my $attr = $ext =~ /ico/ ? 'href' : 'src';

  $t->get_ok('/')->status_is(200)->element_exists($expected_element{$ext}, $ext);
  next unless my $elem = $t->tx->res->dom->at($expected_element{$ext});
  $t->get_ok($elem->{$attr})->status_is(200)
    ->header_is('Content-Type' => $t->app->types->type($ext));
}

done_testing;

__DATA__
@@ index.html.ep
hey!
%= asset '/other/dummy.gif'
%= asset '/other/dummy.ico'
%= asset '/other/dummy.mp3'
%= asset '/other/dummy.mp4'
%= asset '/other/dummy.ogg'
%= asset '/other/dummy.ogv'
%= asset '/other/dummy.svg'
%= asset '/other/dummy.webm'
