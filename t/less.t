use t::Helper;
plan skip_all => 'TEST_LESS=1' unless $ENV{TEST_LESS} or -e '.test-everything';

my $t = t::Helper->t;

$t->app->asset->process('app.css' => 'foo.less');
$t->get_ok('/')->status_is(200)
  ->element_exists(qq(link[href="/asset/fd1bf3a731/foo.css"]));

$t->get_ok($t->tx->res->dom->at('link')->{href})->status_is(200)
  ->content_like(qr{-webkit-box-shadow:})->content_like(qr{color:\s*\#fe33ac});

done_testing;

__DATA__
@@ index.html.ep
%= asset 'app.css'
@@ foo.less
@base: #f938ab;

.box-shadow(@style, @c) when (iscolor(@c)) {
  -webkit-box-shadow: @style @c;
  box-shadow:         @style @c;
}
.box-shadow(@style, @alpha: 50%) when (isnumber(@alpha)) {
  .box-shadow(@style, rgba(0, 0, 0, @alpha));
}
.box {
  color: saturate(@base, 5%);
  border-color: lighten(@base, 30%);
  div { .box-shadow(0 0 5px, 30%) }
}
