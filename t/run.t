use t::Helper;
use Cwd;

plan skip_all => 'Require t/bin/coffee to make failing test' unless -x 't/bin/coffee';

{
  local $ENV{PATH} = join '/', Cwd::getcwd, 't/bin';
  my $t = t::Helper->t({ minify => 1 });
  eval { $t->app->asset('coffee.js' => '/js/c.coffee'); };
  like $@, qr{AssetPack failed to run.*?exit_code=42}, 'exit_code=42';
}

{
  local $ENV{PATH} = 't/bin';
  my $t = t::Helper->t({ minify => 1 });
  eval { $t->app->asset('coffee.js' => '/js/c.coffee'); };
  like $@, qr{AssetPack failed to run.*?exit_code=-1}, 'exit_code=-1';
}


done_testing;
