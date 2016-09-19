use t::Helper;

plan skip_all => 'TEST_ONLINE=1' unless $ENV{TEST_ONLINE} or -e '.test-everything';

$ENV{MOJO_ASSETPACK_CLEANUP} = 0;
$ENV{MOJO_MODE}              = 'production';
my $t = t::Helper->t(pipes => [qw(Sass Fetch Combine)]);
$t->app->asset->process('themed-bootstrap.def');

$t->get_ok('/')->status_is(200);
# this should go to ../assets/.../
$t->get_ok($t->tx->res->dom->at('link')->{href})->status_is(200)
  ->content_like(qr{\Qurl("../assets/BLUNTLIE/fonts/\E});

$ENV{MOJO_ASSETPACK_CLEANUP} = 1;

done_testing;

__DATA__
@@ index.html.ep
%= asset 'app.css'
Hello world
@@ themed-bootstrap.def
! app.css
<< https://raw.githubusercontent.com/twbs/bootstrap-sass/a73cc0f0e5c794206e9a70bc0b67e67cf37c1bca/assets/stylesheets/_bootstrap.scss
< themed-bootstrap.scss
@@ themed-bootstrap.scss
@import "cache/raw.githubusercontent.com/twbs/bootstrap-sass/a73cc0f0e5c794206e9a70bc0b67e67cf37c1bca/assets/stylesheets/_bootstrap.scss";
h1 { color: red; }

