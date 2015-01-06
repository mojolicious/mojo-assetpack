BEGIN { $ENV{MOJO_MODE} //= 'production' }
use t::Helper;
use File::Spec::Functions 'catfile';
use Mojo::Util 'spurt';

my $app = t::Helper->t({})->app;

eval { $app->app->asset('fallback-not-found.js' => '/js/not-found.js'); };
like $@, qr{could not find already packed asset}, 'fallback-not-found.js';

spurt "function fallback(){}\n", catfile qw( t public packed fallback-12345678901234567890123456789012.js );
eval { $app->app->asset('fallback.js' => '/js/not-found.js') };
ok !$@, 'fallback.js' or diag $@;

done_testing;
