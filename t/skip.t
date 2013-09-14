use warnings;
use strict;
use Test::More;
use Test::Mojo;

plan skip_all => 'Not ready for alien host' unless $^O eq 'linux';

my @run;

{
  require Mojolicious::Plugin::AssetPack;
  *Mojolicious::Plugin::AssetPack::_pack_js = sub {
    push @run, [@_];
    print { $_[2] } "dummy();\n";
  };

  use Mojolicious::Lite;
  plugin 'AssetPack' => {
    enable => 1,
    reset => 1,
    yuicompressor => 'dummy',
  };
  app->asset('app.js' => '/js/a.js', '/js/already.min.js');
  get '/js' => 'js';
}

my $t = Test::Mojo->new;

{

  $t->get_ok('/js')
    ->status_is(200)
    ->content_like(qr{<script src="/packed/app\.$^T\.js".*}m)
    ;

  is int @run, 1, 'only packed one file';
  like $run[0][1], qr{a\.js}, 'a.js got compiled';
}

done_testing;
__DATA__
@@ js.html.ep
%= asset 'app.js'
