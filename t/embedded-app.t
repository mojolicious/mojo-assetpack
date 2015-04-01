use t::Helper;
use Cwd;

my $working_dir = getcwd;
my $md5         = '527b09c38362b669ec6e16c00d9fb30d';
my ($embedded, $main);

{
  $embedded = t::Helper->t({minify => 1});
  $embedded->app->asset->preprocessors->remove('js');
  $embedded->app->asset->preprocessors->add(
    js => sub {
      my ($assetpack, $text, $file) = @_;
      $$text = 'var too = "cool";';
    }
  );

  $embedded->app->asset('app.js' => '/js/a.js');
  $embedded->app->routes->get('/', sub { shift->render(text => 'Embedded') });
}

{
  $main = t::Helper->t({minify => 1});
  $main->app->routes->route('/embed')->detour(app => $embedded->app);
  $main->app->routes->get('/main', sub { shift->render(text => 'main') });
}

{
  $embedded->get_ok("/packed/app-$md5.min.js")->status_is(200)->content_is('var too = "cool";');
  $main->get_ok("/main")->status_is(200)->content_is('main');
  $main->get_ok("/embed")->status_is(200)->content_is('Embedded');
  $main->get_ok("/embed/packed/app-$md5.min.js")->status_is(200)->content_is('var too = "cool";');
}

is getcwd, $working_dir, 'did not change directory';

done_testing;
