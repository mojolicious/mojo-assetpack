use t::Helper;
use JavaScript::Minifier::XS;

{
  no warnings 'redefine';
  my $minify = \&JavaScript::Minifier::XS::minify;
  *JavaScript::Minifier::XS::minify = sub {
    push @main::CALLED, $_[0];
    $minify->(@_);
  };
}

my $t = t::Helper->t({minify => 1});

$t->app->asset('app.js' => '/js/a.js', '/js/https___patform_twitter_com_widgets.js');

$t->get_ok('/test1')->status_is(200)
  ->content_like(qr{<script src="/packed/app-8f874fbd5b727a2ec3d94827541b94e9\.min\.js"}m);

is int @main::CALLED, 1, 'minify called once';    # or diag Data::Dumper::Dumper(\@main::CALLED);
like $main::CALLED[0], qr{'a'}, 'a.js got compiled';

done_testing;
__DATA__
@@ test1.html.ep
%= asset 'app.js'
