use t::Helper;
use File::Spec::Functions 'catdir';

plan skip_all => 'TEST_ONLINE=1 required' unless $ENV{TEST_ONLINE};

for my $m (0, 1) {
  my $t = t::Helper->t({minify => $m});
  my $n = 0;
  $t->app->asset('shim.js' => ('http://cdnjs.cloudflare.com/ajax/libs/html5shiv/r29/html5.min.js',));
  my $processed = $t->app->asset->{processed} or next;
  for my $asset (map {@$_} values %$processed) {
    $t->get_ok("/packed/$asset")->status_is(200);
    $n++;
  }
  ok $n, "Generated $n assets with minify=$m";
}

opendir(my $DH, catdir qw( t public packed )) or die $!;
my @assets = grep {/^\w/} sort readdir $DH;
is_deeply(
  \@assets,
  [
    qw(
      _assetpack.map
      http___cdnjs_cloudflare_com_ajax_libs_html5shiv_r29_html5_min_js-720189c61acaa42010a07a70541c04b1.js
      http___cdnjs_cloudflare_com_ajax_libs_html5shiv_r29_html5_min_js.js
      shim-720189c61acaa42010a07a70541c04b1.min.js
      )
  ],
  'generated just the right amount of assets'
);

done_testing;

__DATA__
@@ test1.html.ep
%= asset 'shim.js'
