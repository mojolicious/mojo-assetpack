use t::Helper;

BEGIN {
  package JavaScript::Minifier::XS;
  sub minify { push @main::run, [@_] };
  $INC{'JavaScript/Minifier/XS.pm'} = 'MOCKED';
}

{
  my $t = t::Helper->t({ minify => 1 });

  $t->app->asset('app.js' => '/js/a.js', '/js/already.min.js');

  $t->get_ok('/skip-minified')
    ->status_is(200)
    ->content_like(qr{<script src="/packed/app-ebe7fb100ee204a3db3b8d11a3d46f78\.js".*}m)
    ;

  is int @main::run, 1, 'minify called once';
  like $main::run[0][0], qr{'a'}, 'a.js got compiled';
}

done_testing;
__DATA__
@@ skip-minified.html.ep
%= asset 'app.js'
