use t::Helper;
use File::Spec::Functions 'catdir';

my @READ_ONLY = qw( public read-only-with-source-assets );

local $TODO = 'Need to make this logic more robust before release';

for my $minify (1, 0) {

  diag "generate mapping ($minify)" if $ENV{HARNESS_IS_VERBOS};
  my $t = t::Helper->t({minify => $minify, static => [@READ_ONLY]});
  $t->app->asset('my-plugin-existing.css' => qw( /css/my-plugin-a.css /css/my-plugin-b.css ));
  $t->get_ok('/test1')->status_is(200)->content_like(qr/color:\s*\#aaa.*color:\s*\#bbb/s);
  $t->app->asset->save_mapping;

  diag "use fixed mapping" if $ENV{HARNESS_IS_VERBOS};
  $t = t::Helper->t({minify => $minify, static => [$READ_ONLY[0]]});
  $t->app->asset('my-plugin-existing.css' => qw( /css/my-plugin-a.css /css/my-plugin-b.css ));
  $t->get_ok('/test1')->status_is(200)->content_like(qr/color:\s*\#aaa.*color:\s*\#bbb/s);
}

done_testing;
__DATA__
@@ test1.html.ep
%= asset 'my-plugin-existing.css', { inline => 1 }
