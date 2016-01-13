BEGIN { $ENV{MOJO_MODE} = 'not_development' }
use t::Helper;
my $t = t::Helper->t;

plan skip_all => 'cpanm CSS::Sass' unless eval 'require CSS::Sass;1';

# Assets from __DATA__
$t->app->asset->process('app.css' => ('sass-0-one.sass', 'sass-0-two.scss'));
$t->get_ok('/')->status_is(200)
  ->element_exists(qq(link[href="/asset/646e18d0d7/app.css"]));

$t->get_ok($t->tx->res->dom->at('link:nth-of-child(1)')->{href})->status_is(200)
  ->content_like(qr{\.sass\W+color:\s+\#aaa.*\.scss \.nested\W+color:\s+\#909090}s);

Mojo::Util::monkey_patch('CSS::Sass', sass2scss => sub { die 'Nope!' });
$ENV{MOJO_ASSETPIPE_CLEANUP} = 0;
$t = t::Helper->t;
ok eval { $t->app->asset->process('app.css' => ('sass-0-one.sass', 'sass-0-two.scss')) },
  'using cached assets'
  or diag $@;
$ENV{MOJO_ASSETPIPE_CLEANUP} = 1;

# Assets from disk
$t = t::Helper->t;
$t->app->asset->process('app.css' => 'sass/sass-1.scss');
$t->get_ok('/')->status_is(200)
  ->element_exists(qq(link[href="/asset/4abbb4a8c8/app.css"]));
$t->get_ok($t->tx->res->dom->at('link:nth-of-child(1)')->{href})->status_is(200)
  ->content_like(qr{footer.*\#aaa.*body.*\#222}s);

done_testing;

__DATA__
@@ index.html.ep
%= asset 'app.css'
@@ sass-0-one.sass
$color: #aaa;
.sass
  color: $color;
@@ sass-0-two.scss
$color: #aaa;
.scss {
  color: $color;
  .nested { color: darken($color, 10%); }
}
