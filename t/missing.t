use warnings;
use strict;
use Test::More;
use Test::Mojo;

my $md5 = '81e6a22b62fc6e28e355713517fdc3d8';

BEGIN { $ENV{PATH} = '' }

{
  use Mojolicious::Lite;
  plugin 'AssetPack' => { minify => 1 };
  app->asset('one.foo' => '/dummy.foo');
  app->asset('two.css' => '/sass/x.scss');
  app->asset('three.css' => '/css/a.less');
  get '/foo' => 'foo';
}

my $t = Test::Mojo->new;

{
  $t->get_ok('/foo')
    ->element_exists(qq([href="/Mojolicious/Plugin/AssetPack/could/not/compile/one.foo"]))
    ->element_exists(qq([href="/Mojolicious/Plugin/AssetPack/could/not/compile/two.css"]))
    ->element_exists(qq([href="/Mojolicious/Plugin/AssetPack/could/not/compile/three.css"]))
    ->status_is(200)
    ;

  $t->get_ok("/packed/one.foo")->status_is(404);
  $t->get_ok("/packed/two.css")->status_is(404);
  $t->get_ok("/packed/three.css")->status_is(404);
}

done_testing;
__DATA__
@@ foo.html.ep
%= asset 'one.foo'
%= asset 'two.css'
%= asset 'three.css'
