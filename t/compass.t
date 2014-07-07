use t::Helper;
use File::Which;

my $compass = which 'compass';
my $expected = $compass ? qr{\babcdef\b} : qr{ERROR:\|Unable to load Compass}i;

{
  diag "minify=0";
  my $t = t::Helper->t({ minify => 1 });

  plan skip_all => 'Could not find preprocessors for scss', 6 unless $t->app->asset->preprocessors->has_subscribers('scss');

  $t->app->asset('compass.css' => '/sass/compass.scss');
  $t->get_ok('/compass')->status_is(200);
  $t->get_ok($t->tx->res->dom->at('link')->{href})->status_is(200)->content_like($expected, $expected);
}

done_testing;

__DATA__
@@ compass.html.ep
%= asset 'compass.css'
