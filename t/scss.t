use t::Helper;

{
  my $t = t::Helper->t({minify => 0});

  plan skip_all => 'Could not find preprocessors for scss' unless $t->app->asset->preprocessors->can_process('scss');

  $t->app->asset('scss.css' => '/css/a.scss', '/css/b.scss');

  # test "sass -I" (--load-path)
  $t->app->asset('include-dir.css' => '/sass/y.scss');
  $t->app->routes->get('/include-dir' => 'include-dir');

  # Fix bug when asset has the same moniker as one of the source files (0.0601)
  $t->app->asset('x.css' => '/sass/x.scss');
  $t->app->routes->get('/x' => 'x');

  $t->get_ok('/test1')->status_is(200)->content_like(qr{<link href="/packed/a-\w+\.css"})
    ->content_like(qr{<link href="/packed/b-\w+\.css"});

  $t->get_ok('/x')->status_is(200)->content_like(qr{<link href="/packed/x-\w+\.css"});

  $t->get_ok($t->tx->res->dom->at('link')->{href})->status_is(200)->content_like(qr{background: \#abcdef});

  $t->get_ok('/include-dir')->content_like(qr{<link href="/packed/y-05a6bb2d52a836b9f06a0e9211084984\.css"}m)
    ->status_is(200);
}

{
  my $t = t::Helper->t({minify => 1});

  $t->app->asset('scss.css' => '/css/a.scss', '/css/b.scss');

  $t->get_ok('/test1')->status_is(200)
    ->content_like(qr{<link href="/packed/scss-53f756a54b650d23d1ddb705c10c97d6\.min\.css"}m);

  $t->get_ok($t->tx->res->dom->at('link')->{href})->status_is(200)->content_like(qr{a1a1a1.*b1b1b1}s);
}

is(Mojolicious::Plugin::AssetPack::Preprocessor::Scss->_url, 'http://sass-lang.com/install', '_url');

{
  # https://github.com/jhthorsen/mojolicious-plugin-bootstrap3/issues/5
  my $scss_file = File::Spec->catfile(qw( t public sass subdir _issue-5.scss ));
  my ($app, $scss);

  $app = t::Helper->t->app;
  $app->asset('change.css' => '/sass/bs-issue-5.scss');
  like + ($app->asset->get('change.css', {assets => 1}))[0]->slurp, qr{\#b00}, 'original';

  use Mojo::Util qw( slurp spurt );
  $scss = slurp $scss_file;
  $scss =~ s!b00!00b!;
  spurt $scss => $scss_file;

  $app = t::Helper->t->app;
  $app->asset('change.css' => '/sass/bs-issue-5.scss');
  like + ($app->asset->get('change.css', {assets => 1}))[0]->slurp, qr{\#00b}, 'updated';

  $scss =~ s!00b!b00!;
  spurt $scss => $scss_file;
}

{
  # https://github.com/jhthorsen/mojolicious-plugin-assetpack/pull/60

  local $ENV{SASS_PATH} = File::Spec->catdir(
    File::Spec->rel2abs( File::Spec->curdir ),
    qw( t public sass anotherdir)
  );

  my $scss_file = File::Spec->catfile(
    qw( t public sass anotherdir subdir _issue-60.scss )
  );
  my ($app, $scss);

  $app = t::Helper->t->app;
  $app->asset('change.css' => '/sass/issue-60.scss');
  like + ($app->asset->get('change.css', {assets => 1}))[0]->slurp, qr{\#bbb}, 'original';

  use Mojo::Util qw( slurp spurt );
  $scss = slurp $scss_file;
  $scss =~ s!bbb!ccc!;
  spurt $scss => $scss_file;

  $app = t::Helper->t->app;
  $app->asset('change.css' => '/sass/issue-60.scss');
  like + ($app->asset->get('change.css', {assets => 1}))[0]->slurp, qr{\#ccc}, 'updated';

  $scss =~ s!ccc!bbb!;
  spurt $scss => $scss_file;
}

done_testing;

__DATA__
@@ test1.html.ep
%= asset 'scss.css'
@@ x.html.ep
%= asset 'x.css'
@@ include-dir.html.ep
%= asset 'include-dir.css'
