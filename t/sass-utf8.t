use t::Helper;
use utf8;
plan skip_all => 'cpanm CSS::Sass' unless eval 'use CSS::Sass 3.3.0;1';

my $t = t::Helper->t(pipes => ['Sass']);
$t->app->asset->process('app.css' => ('sass/70-utf8.scss'));
$t->get_ok('/')->status_is(200);
$t->get_ok($t->tx->res->dom->at('link')->{href})->status_is(200)
  ->content_like(qr{コメント});

done_testing;
__DATA__
@@ index.html.ep
%= asset 'app.css'
