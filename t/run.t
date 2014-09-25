use t::Helper;
use Cwd;

plan skip_all => 'Require t/bin/coffee to make failing test' unless -x 't/bin/coffee';

{
  local $ENV{PATH} = join '/', Cwd::getcwd, 't/bin';
  my $t = t::Helper->t({ minify => 1 });
  $t->app->asset('coffee.js' => '/js/c.coffee');
  $t->get_ok('/run')->element_exists('script[src]');
  $t->get_ok($t->tx->res->dom->at('script')->{src})
    ->content_unlike(qr{[\n\r]})
    ->content_like(qr{^alert\('AssetPack failed to run.*exit_code=42});

  my $t = t::Helper->t({ minify => 1 });
  $t->app->asset('sass.css' => '/sass/a.sass');
  $t->get_ok('/run')->element_exists('link[href]');
  $t->get_ok($t->tx->res->dom->at('link')->{href})
    ->content_unlike(qr{[\n\r]})
    ->content_like(qr{^html:before.*AssetPack failed to run.*exit_code=-1});
}

done_testing;
__DATA__
@@ run.html.ep
%= asset 'coffee.js'
%= asset 'sass.css'
