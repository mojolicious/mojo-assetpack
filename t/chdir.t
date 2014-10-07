use Test::More;
use Mojolicious::Plugin::AssetPack::Preprocessors;

ok -e 'cpanfile', 'root dir';

my $cwd = Mojolicious::Plugin::AssetPack::Preprocessors::CWD->new('t');
ok -e 'chdir.t', 'chdir to t';

undef $cwd;
ok -e 'cpanfile', 'chdir back';

done_testing;
