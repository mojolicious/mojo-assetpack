use t::Helper;
my $t = t::Helper->t;

plan skip_all => 'TEST_ONLINE=1' unless $ENV{TEST_ONLINE} or -e '.test-everything';
plan skip_all => 'cpanm CSS::Sass' unless eval 'require CSS::Sass;1';

$t->app->asset->process(
  'app.css' => (
    'https://raw.githubusercontent.com/hugeinc/flexboxgrid-sass/master/demo/sass/demo.scss'
  )
);

$t->get_ok('/')->status_is(200)
  ->element_exists(qq(link[href="/asset/742ef01e93/demo.css"]));

# comment from https://github.com/hugeinc/flexboxgrid-sass/blob/master/demo/sass/_code.scss
$t->get_ok($t->tx->res->dom->at('link')->{href})->status_is(200)
  ->content_like(qr{Tomorrow Theme}s);

unlink File::Spec->catfile(
  qw(t assets cache raw.githubusercontent.com hugeinc flexboxgrid-sass master demo sass _code.scss)
);
done_testing;

__DATA__
@@ index.html.ep
%= asset 'app.css'
