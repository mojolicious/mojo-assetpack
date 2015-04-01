use t::Helper;

my $src = File::Spec->catfile(qw( t public css bootstrap-0cbacb97f7b3f70fb6d39926d48dba68.css ));
my $dst = File::Spec->catfile(qw( t public packed bootstrap-0cbacb97f7b3f70fb6d39926d48dba68.css ));

my $t = t::Helper->t({minify => 1});

if ($ENV{TEST_BOOTSTRAP3} and eval { $t->app->plugin('Bootstrap3') }) {
  $t->get_ok('/test1')->status_is(200)->content_like(qr{<link href="/packed/bootstrap-\w+\.css"}m);
  $t->get_ok($t->tx->res->dom->at('link')->{href})->status_is(200)->content_like(qr{\.table-responsive});
}
else {
  plan skip_all => "bootstrap-0cbacb97f7b3f70fb6d39926d48dba68.css: $!" unless link $src, $dst;
  $t->app->asset('bootstrap.css' => '/css/d.css', '/css/c.css');
  $t->get_ok('/test1')->status_is(200)
    ->content_like(qr{<link href="/packed/bootstrap-0cbacb97f7b3f70fb6d39926d48dba68\.css"}m);
  $t->get_ok($t->tx->res->dom->at('link')->{href})->status_is(200)->content_like(qr{d1d1d1.*c1c1c1});
}

done_testing;

END { unlink $dst }

__DATA__
@@ test1.html.ep
%= asset 'bootstrap.css'
