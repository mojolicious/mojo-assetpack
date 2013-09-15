use warnings;
use strict;
use Test::More;
use Test::Mojo;

plan skip_all => 'Not ready for alien host' unless $^O eq 'linux';

my @run;

{
  use Mojolicious::Lite;
  plugin 'AssetPack' => { minify => 1, rebuild => 1 };
  *JavaScript::Minifier::XS::minify = sub { push @run, [@_] };
  app->asset('app.js' => '/js/a.js', '/js/already.min.js');
  get '/js' => 'js';
}

my $t = Test::Mojo->new;

{

  $t->get_ok('/js')
    ->status_is(200)
    ->content_like(qr{<script src="/packed/app\.$^T\.js".*}m)
    ;

  is int @run, 1, 'minify called once';
  like $run[0][0], qr{'a'}, 'a.js got compiled';
}

done_testing;
__DATA__
@@ js.html.ep
%= asset 'app.js'
