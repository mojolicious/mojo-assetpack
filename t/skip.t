use warnings;
use strict;
use Test::More;
use Test::Mojo;

plan skip_all => 'Not ready for alien host' unless $^O eq 'linux';

my @run;

{
  use Mojolicious::Lite;
  plugin 'AssetPack' => {
    minify => 1,
    rebuild => 1,
  };
  app->asset->preprocessor(js => sub {
    push @run, [@_];
    return;
  });
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
