use t::Helper;
use File::Spec::Functions qw( catdir catfile );

$ENV{PATH} = catdir(Cwd::getcwd, 't', 'bin');
plan
  skip_all => 'Require t/bin/coffee to make failing test'
  unless -x catfile $ENV{PATH},
  'coffee';

local $ENV{MOJO_MODE} = 'some-production-mode';
my $t = t::Helper->t_old({minify => 1});

$ENV{EXITCODE} = 42;
eval { $t->app->asset('coffee.js' => '/js/c.coffee') };
like $@, qr(Failed to run),
  'will not load application on process error in non-development mode';

eval { $t->app->asset('invalid.foo' => '/dummy.foo') };
like $@, qr(No preprocessor defined),
  'will not load application without preprocessors in non-development mode';

done_testing;
__DATA__
@@ test1.html.ep
%= asset 'coffee.js'
%= asset 'invalid.foo'
