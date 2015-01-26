use t::Helper;
use File::Spec::Functions qw( catdir catfile );

$ENV{PATH} = catdir(Cwd::getcwd, 't', 'bin');
plan skip_all => 'Require t/bin/coffee to make failing test' unless -x catfile $ENV{PATH}, 'coffee';

my @res = (
  {
    coffee  => '/packed/c-accff0dbd3d143a751e4d54eea182cfa-with-error.js',
    style   => '/packed/x-19455f135dea3f162e486f8a734f0069-with-error.css',
    invalid => '/packed/dummy-81e6a22b62fc6e28e355713517fdc3d8-with-error.foo',
  },
  {
    coffee  => '/packed/coffee-accff0dbd3d143a751e4d54eea182cfa-with-error.js',
    style   => '/packed/style-19455f135dea3f162e486f8a734f0069-with-error.css',
    invalid => '/packed/invalid-81e6a22b62fc6e28e355713517fdc3d8-with-error.foo',
  }
);

for my $x (0, 1) {
  $ENV{MOJO_MODE} = $x ? 'production' : 'development';
  my $t = t::Helper->t({minify => $x});
  my $file;

  $ENV{EXITCODE} = 42;
  $t->app->asset('coffee.js'   => '/js/c.coffee');
  $t->app->asset('style.css'   => '/sass/x.scss');
  $t->app->asset('invalid.foo' => '/dummy.foo');

  $t->get_ok('/test1')->status_is(200);

  my %src = (
    coffee  => eval { $t->tx->res->dom->at('script[src]')->{src} },
    invalid => eval { $t->tx->res->dom->find('link[href]')->[0]{href} },
    style   => eval { $t->tx->res->dom->find('link[href]')->[1]{href} },
  );

  is_deeply(\%src, shift(@res), 'found elements');

  $file = $x ? 'coffee\.js' : '.*?\Wc.coffee';
  $t->get_ok($src{coffee})->status_is(200)->content_unlike(qr{[\n\r]})
    ->content_like(qr{^alert\('$file: Failed to run .*coffee.*\(\$\?=42, \$!=25\) Whoopsie'\);console\.log},
    "coffee 42 ($x)");

  $file = $x ? 'invalid\.foo' : '.*?\Wdummy.foo';
  $t->get_ok($src{invalid})->status_is(200)
    ->content_like(qr/^html:before{.*content:"$file: No preprocessor defined for .*dummy\.foo";}/, "invalid ($x)");

  $file = $x ? 'style\.css' : '.*?\Wx.scss';
  $t->get_ok($src{style})->status_is(200)->content_unlike(qr{[\n\r]})
    ->content_like(qr|^html:before{.*content:"$file: Cannot execute 'sass'\. See http://sass-lang\.com/install"|,
    "style ($x)");

  diag 'with-error files are always generated';
  $ENV{EXITCODE} = 31;
  $file = $x ? 'coffee\.js' : '.*?\Wc.coffee';
  $t->app->asset('coffee.js' => '/js/c.coffee');
  $t->get_ok($src{coffee})->status_is(200)->content_unlike(qr{[\n\r]})
    ->content_like(qr{^alert\('$file: Failed to run .*coffee.*\(\$\?=31, \$!=25\) Whoopsie'\);console\.log},
    "coffee 31 ($x)");
}

done_testing;
__DATA__
@@ test1.html.ep
%= asset 'coffee.js'
%= asset 'invalid.foo'
%= asset 'style.css'
