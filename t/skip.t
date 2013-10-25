use warnings;
use strict;
use Test::More;
use Test::Mojo;

BEGIN {
  package JavaScript::Minifier::XS;
  sub minify { push @main::run, [@_] };
  $INC{'JavaScript/Minifier/XS.pm'} = 'MOCKED';
}

plan skip_all => 'Not ready for alien host' unless $^O eq 'linux';

{
  use Mojolicious::Lite;
  plugin 'AssetPack' => { minify => 1, rebuild => 1 };
  app->asset('app.js' => '/js/a.js', '/js/already.min.js');
  get '/js' => 'js';
}

my $t = Test::Mojo->new;

{

  $t->get_ok('/js')
    ->status_is(200)
    ->content_like(qr{<script src="/packed/app-3ed8fc2cff5774822803ff18cc2c4487\.js".*}m)
    ;

  is int @main::run, 1, 'minify called once';
  like $main::run[0][0], qr{'a'}, 'a.js got compiled';
}

done_testing;
__DATA__
@@ js.html.ep
%= asset 'app.js'
