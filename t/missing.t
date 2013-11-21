use warnings;
use strict;
use Test::More;
use Test::Mojo;

my $md5 = '81e6a22b62fc6e28e355713517fdc3d8';

{
  open my $FOO, '>', "t/public/packed/app-$md5.foo" or plan skip_all => $!;
  print $FOO "hello world\n";
  close $FOO;
}

{
  use Mojolicious::Lite;
  plugin 'AssetPack' => { minify => 1 };
  app->asset('app.foo' => '/dummy.foo');
  get '/foo' => 'foo';
}

my $t = Test::Mojo->new;

{
  $t->get_ok('/foo')->content_like(qr{$md5})->status_is(200);
  $t->get_ok("/packed/app-$md5.foo")->status_is(200)->content_is("hello world\n");
}

done_testing;
__DATA__
@@ foo.html.ep
%= asset 'app.foo'
