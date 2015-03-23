BEGIN { $ENV{ENABLE_LIBSASS_BINDINGS} = 0 }
use t::Helper;
use File::Which;

my $t = t::Helper->t({minify => 1});

plan skip_all => 'Need to install sass+compass'          unless which 'compass';
plan skip_all => 'Could not find preprocessors for scss' unless $t->app->asset->preprocessors->can_process('scss');

$t->app->asset('compass.css' => '/sass/compass.scss');
$t->get_ok('/test1')->status_is(200);
$t->get_ok($t->tx->res->dom->at('link')->{href})->status_is(200)->content_like(qr{\babcdef\b});

done_testing;

__DATA__
@@ test1.html.ep
%= asset 'compass.css'
