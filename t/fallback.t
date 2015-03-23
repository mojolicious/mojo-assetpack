BEGIN { $ENV{MOJO_MODE} //= 'production' }
use t::Helper;
use File::Spec::Functions 'catfile';
use Mojo::Util 'spurt';
use Mojolicious::Plugin::AssetPack::Preprocessor::Fallback;

my $app = t::Helper->t({})->app;

eval { $app->app->asset('fallback-not-found.js' => '/js/not-found.js'); };
like $@, qr{could not find already packed asset}, 'fallback-not-found.js';

spurt "function fallback(){}\n", catfile qw( t public packed fallback-12345678901234567890123456789012.js );
eval { $app->app->asset('fallback.js' => '/js/not-found.js') };
ok !$@, 'fallback.js' or diag $@;

is(Mojolicious::Plugin::AssetPack::Preprocessor::Fallback->can_process, 0, 'cannot process');
is(
  Mojolicious::Plugin::AssetPack::Preprocessor::Fallback->_url,
  'https://metacpan.org/pod/Mojolicious::Plugin::AssetPack::Preprocessors',
  'default _url()'
);

done_testing;
