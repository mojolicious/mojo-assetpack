use lib '.';
use t::Helper;
plan skip_all => 'cpanm CSS::Sass' unless eval 'use CSS::Sass 3.3.0;1';

my $t = t::Helper->t(pipes => [qw(Sass Css)]);

$t->app->asset->pipe('Sass')->functions({
  q[image-url($arg)] => sub { return sprintf "url(/assets/%s)", $_[1] }
});

$t->app->asset->process('app.css' => 'functions.scss');
$t->get_ok('/')->status_is(200);
$t->get_ok($t->tx->res->dom->at('link')->{href})->status_is(200)->content_like(qr{body.*url\(/assets/img\.png}s);

done_testing;

__DATA__
@@ index.html.ep
%= asset 'app.css'
@@ functions.scss
body {
  background: #fff image-url('img.png') top left;
}
