use t::Helper;
use File::Spec::Functions 'catdir';

my @READ_ONLY = qw( public read-only-with-source-assets );

for my $minify (1, 0) {

  # add mapping to existing asset
  my $t = t::Helper->t({minify => $minify, fallback_to_latest => 1, static => [@READ_ONLY]});

  # add fallback_to_latest asset, which should be ignored in all cases
  my $latest = $t->app->asset->_asset("packed/my-plugin-existing-11111111111111111111111111111111.css")
    ->spurt('/* ignore-even-with-latest-mtime */');

  diag "generate mapping ($minify)" if $ENV{HARNESS_IS_VERBOS};
  $t->app->asset('my-plugin-existing.css' => qw( /css/my-plugin-a.css /css/my-plugin-b.css ));
  $t->get_ok('/test1')->status_is(200)->content_like(qr/color:\s*\#aaa.*color:\s*\#bbb/s);
  $t->app->asset->save_mapping;

  diag "use fixed mapping, instead of 11111111111111111111111111111111.css" if $ENV{HARNESS_IS_VERBOS};
  $t = t::Helper->t({minify => $minify, fallback_to_latest => 1, static => [$READ_ONLY[0]]});
  $t->app->asset('my-plugin-existing.css' => qw( /css/my-plugin-a.css /css/my-plugin-b.css ));
  $t->get_ok('/test1')->status_is(200)->content_like(qr/color:\s*\#aaa.*color:\s*\#bbb/s);
  unlink $latest->path;
}

done_testing;
__DATA__
@@ test1.html.ep
%= asset 'my-plugin-existing.css', { inline => 1 }
