use t::Helper;
use File::Spec::Functions 'catdir';

my $public_dir = 'public';
my $source_dir = 'read-only-with-source-assets';

for my $minify (0, 1) {

  diag "generate mapping ($minify)" if $ENV{HARNESS_IS_VERBOS};
  my $t = t::Helper->t({minify => $minify, static => [$public_dir, $source_dir]});
  $t->app->asset('my-plugin-existing.css' => qw( /css/my-plugin-a.css /css/my-plugin-b.css ));
  $t->get_ok('/test1')->status_is(200)->content_like(qr/color:\s*\#aaa.*color:\s*\#bbb/s);

  diag "use fixed mapping" if $ENV{HARNESS_IS_VERBOS};
  $t = t::Helper->t({minify => $minify, static => [$public_dir]});
  $t->app->asset('my-plugin-existing.css' => qw( /css/my-plugin-a.css /css/my-plugin-b.css ));
  $t->get_ok('/test1')->status_is(200)->content_like(qr/color:\s*\#aaa.*color:\s*\#bbb/s);
}

done_testing;
__DATA__
@@ test1.html.ep
%= asset 'my-plugin-existing.css', { inline => 1 }
