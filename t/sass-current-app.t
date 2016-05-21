use t::Helper;
plan skip_all => 'cpanm CSS::Sass' unless eval 'use CSS::Sass 3.3.0;1';

my $t = t();
$t->app->asset->process;

$t->get_ok('/')->status_is(200)
  ->element_exists(qq(link[href="/asset/cbac517842/main.css"]));
$t->get_ok($t->tx->res->dom->at('link')->{href})->status_is(200)
  ->content_unlike(qr{green.*green}s)->content_like(qr{green;}s);

{
  local $ENV{MOJO_ASSETPACK_CLEANUP} = 0;
  undef $t;
}

$ENV{MOJO_MODE} = 'Test_minify_from_here';
$t = t();
$t->app->asset->process;

$t->get_ok('/')->status_is(200)
  ->element_exists(qq(link[href="/asset/98f95f2ef4/app.css"]));
$t->get_ok($t->tx->res->dom->at('link')->{href})->status_is(200)
  ->content_unlike(qr{green.*green}s)->content_like(qr{green\b}s);

unlink File::Spec->catfile(qw(t assets cache main-36fb02dacb.css));
unlink File::Spec->catfile(qw(t assets cache local sass forms _forms.scss));
unlink File::Spec->catfile(qw(t assets cache local sass forms _input-fields.scss));

done_testing;

sub t {
  my $t = t::Helper->t(pipes => [qw(Css Sass Combine)]);
  my $r = $t->app->routes;
  $r->get('/sass/ext.scss'                 => {text => qq(\@import "forms/forms";\n)});
  $r->get('/sass/forms/_forms.scss'        => {text => qq(\@import 'input-fields';\n)});
  $r->get('/sass/forms/_input-fields.scss' => {text => "form {text: green;}\n"});
  $t;
}

__DATA__
@@ index.html.ep
%= asset 'app.css'
@@ assetpack.def
! app.css
<< http://local/sass/ext.scss
< main.scss
@@ main.scss
@import "cache/local/sass/forms/forms";
