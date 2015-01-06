use Mojo::Base -strict;
use Test::More;
use Mojolicious::Plugin::AssetPack::Preprocessor::Browserify;

my $p = Mojolicious::Plugin::AssetPack::Preprocessor::Browserify->new;

plan skip_all => 'npm install browserify' if $p->executable eq 'browserify';

is $p->environment, 'development', 'default environment';
is_deeply($p->extensions, ['js'], 'default extensions');
ok $p->can_process, 'can_process';

done_testing;
