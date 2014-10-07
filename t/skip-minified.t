use t::Helper;

BEGIN {

  package JavaScript::Minifier::XS;
  sub minify { push @main::run, [@_] }
  $INC{'JavaScript/Minifier/XS.pm'} = 'MOCKED';
}

{
  my $t = t::Helper->t({minify => 1});

  $t->app->asset('app.js' => '/js/a.js', '/js/already.min.js');

  $t->get_ok('/test1')->status_is(200)
    ->content_like(qr{<script src="/packed/app-9f544b9fe09441cb64e52620223f413a\.js".*}m);

  is int @main::run, 1, 'minify called once';
  like $main::run[0][0], qr{'a'}, 'a.js got compiled';
}

done_testing;
__DATA__
@@ test1.html.ep
%= asset 'app.js'
