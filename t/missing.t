use t::Helper;
use File::Spec::Functions qw( catdir catfile );

$ENV{PATH} = catdir(Cwd::getcwd, 't', 'bin');
plan skip_all => 'Require t/bin/coffee to make failing test' unless -x catfile $ENV{PATH}, 'coffee';

{
  local $ENV{MOJO_MODE} = 'some-production-mode';
  my $t = t::Helper->t({minify => 1});

  $ENV{EXITCODE} = 42;
  eval { $t->app->asset('coffee.js' => '/js/c.coffee') };
  like $@, qr(Failed to run), 'will not load application on process error in non-development mode';

  eval { $t->app->asset('invalid.foo' => '/dummy.foo') };
  like $@, qr(No preprocessor defined), 'will not load application without preprocessors in non-development mode';

  # This feature is tested, but not documented
  local $ENV{MOJO_ASSETPACK_DIE_ON_PROCESS_ERROR} = 0;
  $t = t::Helper->t({minify => 1});
  is eval { $t->app->asset('coffee.js' => '/js/c.coffee'); 1 }, 1, 'MOJO_ASSETPACK_DIE_ON_PROCESS_ERROR=0' or diag $@;
}

{
  local $ENV{MOJO_MODE} = 'development';
  my $t = t::Helper->t({minify => 0});
  my ($dom, %src);

  $ENV{EXITCODE} = 42;
  $t->app->asset('coffee.js'   => '/js/c.coffee');
  $t->app->asset('invalid.foo' => '/dummy.foo');

  $t->get_ok('/test1')->status_is(200);
  $dom = $t->tx->res->dom;
  %src = (coffee => $dom->at('script[src]')->{src}, invalid => $dom->at('link[href]')->{href});

  is_deeply(
    \%src,
    {
      coffee  => '/packed/c-accff0dbd3d143a751e4d54eea182cfa.err.js',
      invalid => '/packed/dummy-81e6a22b62fc6e28e355713517fdc3d8.err.foo',
    },
    'error assets are generated in development mode'
  );

  $t->get_ok($src{coffee})->status_is(200)->content_unlike(qr{[\n\r]})
    ->content_like(qr{^alert\('c\.coffee: Failed to run .*coffee.*\(\$\?=42, \$!=\d+\) Whoopsie'\);console\.log},
    "coffee.js 42 content");

  $t->get_ok($src{invalid})->status_is(200)
    ->content_like(qr/^html:before\{.*content:"dummy\.foo: No preprocessor defined for .*dummy\.foo";\}/,
    "invalid.foo content");

  # error files are always generated
  $ENV{EXITCODE} = 31;
  $t->app->asset('coffee.js' => '/js/c.coffee');
  $t->get_ok($src{coffee})->status_is(200)->content_unlike(qr{[\n\r]})
    ->content_like(qr{^alert\('c\.coffee: Failed to run .*coffee.*\(\$\?=31, \$!=\d+\) Whoopsie'\);console\.log},
    "coffee.js 31 content");
}

done_testing;
__DATA__
@@ test1.html.ep
%= asset 'coffee.js'
%= asset 'invalid.foo'
