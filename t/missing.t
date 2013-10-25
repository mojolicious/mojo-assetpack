use warnings;
use strict;
use Test::More;
use Test::Mojo;
use Mojo::Util 'md5_sum';

my $md5 = md5_sum "hello world\n";

{
  open my $FOO, '>', "t/public/packed/app-$md5.foo" or plan skip_all => $!;
  print $FOO "hello world\n";
  close $FOO;
}

{
  use Mojolicious::Lite;
  plugin 'AssetPack' => { minify => 1, rebuild => 1 };
  app->asset('app.foo' => '/js/a.foo', '/js/already.min.foo');
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
