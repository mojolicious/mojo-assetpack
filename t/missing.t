BEGIN { $ENV{PATH} = '/dev/null'; }
use t::Helper;

{
  my $t = t::Helper->t({ minify => 1 });

  $t->app->asset('one.foo' => '/dummy.foo');
  $t->app->asset('two.css' => '/sass/x.scss');

  $t->get_ok('/missing')
    ->status_is(200)
    ->element_exists(qq([href="/Mojolicious/Plugin/AssetPack/could/not/compile/one.foo"]), 'one.foo')
    ->element_exists(qq([href="/packed/two-19455f135dea3f162e486f8a734f0069.css"]), 'two.css')
    ;

  $t->get_ok('/packed/one.foo')->status_is(404);
  $t->get_ok('/packed/two-19455f135dea3f162e486f8a734f0069.css')->status_is(200)->content_like(qr{content:"AssetPack failed});
}

done_testing;
__DATA__
@@ missing.html.ep
%= asset 'one.foo'
%= asset 'two.css'
%= asset 'three.css'
