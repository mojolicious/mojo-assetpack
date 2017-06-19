use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use Mojolicious::Plugin::AssetPack::Util qw($CWD diag has_ro);
use Mojolicious::Plugin::AssetPack::Pipe::Sass;

has_ro 'no_builder';
has_ro with_builder => sub {42};

my $obj = bless {}, __PACKAGE__;

eval { $obj->no_builder(1) };
like $@, qr{read-only}, 'no_builder read-only';
eval { $obj->no_builder };
like $@, qr{required in constructor}, 'no_builder';
$obj->{no_builder} = 'yay!';
is $obj->no_builder, 'yay!', 'no_builder with value';

eval { $obj->with_builder(1) };
like $@, qr{read-only}, 'with_builder read-only';
is $obj->with_builder, 42, 'with_builder';

{
  my $diag = '';
  local $SIG{__WARN__} = sub { $diag = $_[0] };
  diag 'foo';
  like $diag, qr{\[AssetPack\] foo\n}, 'diag foo';
  diag 'foo %s', 'bar';
  like $diag, qr{\[AssetPack\] foo bar\n}, 'diag foo bar';
}

my $dir = $CWD;

{
  local $CWD = File::Spec->tmpdir;
  isnt $CWD, $dir, 'chdir';
}

is $dir, Cwd::getcwd, 'back on track';

for my $name (qw(gem node ruby)) {
  my $method = "_install_$name";
  eval { Mojolicious::Plugin::AssetPack::Pipe::Sass->new->$method };
  like $@, qr{Mojolicious::Plugin::AssetPack::Pipe::Sass requires.*$name.*http}, $method;
}

done_testing;
