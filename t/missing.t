use warnings;
use strict;
use Test::More;
use Test::Mojo;

{
  open my $FOO, '>', 't/public/packed/app.foo' or plan skip_all => $!;
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
  $t->get_ok('/foo')->status_is(200);
  $t->get_ok('/packed/app.123.foo')->status_is(200)->content_is("hello world\n");
}

done_testing;
__DATA__
@@ foo.html.ep
%= asset 'app.foo'
