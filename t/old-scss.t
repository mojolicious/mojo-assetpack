use t::Helper;

{
  my $t = t::Helper->t_old({minify => 0});

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
  my $t = t::Helper->t_old({minify => 1});

  $t->app->asset('scss.css' => '/css/a.scss', '/css/b.scss');

  $t->get_ok('/test1')->status_is(200)
    ->content_like(qr{<link href="/packed/scss-53f756a54b650d23d1ddb705c10c97d6\.min\.css"}m);

  $t->get_ok($t->tx->res->dom->at('link')->{href})->status_is(200)->content_like(qr{a1a1a1.*b1b1b1}s);
}

is(Mojolicious::Plugin::AssetPack::Preprocessor::Scss->_url, 'http://sass-lang.com/install', '_url');

{
  # https://github.com/jhthorsen/mojolicious-plugin-bootstrap3/issues/5
  my $scss_file = File::Spec->catfile(qw( t public sass subdir _issue-5.scss ));
  my $app       = t::Helper->t_old->app;
  $app->asset('change.css' => '/sass/bs-issue-5.scss');
  like + ($app->asset->get('change.css', {assets => 1}))[0]->slurp, qr{\#b00}, 'original';

  modify($scss_file, sub {s!b00!00b!});
  $app = t::Helper->t_old->app;
  $app->asset('change.css' => '/sass/bs-issue-5.scss');
  like + ($app->asset->get('change.css', {assets => 1}))[0]->slurp, qr{\#00b}, 'updated';

  modify($scss_file, sub {s!00b!b00!});    # reset
}

{
  # https://github.com/jhthorsen/mojolicious-plugin-assetpack/pull/60

  local $ENV{SASS_PATH} = join(':',
    '/will/not/find/anything/here',
    File::Spec->catdir(File::Spec->rel2abs(File::Spec->curdir), qw( t public anotherdir )),
    '/other/directory');

  # SASS_PATH
  my $app       = t::Helper->t_old->app;
  my $scss_file = File::Spec->catfile(qw( t public anotherdir subdir _issue-60.scss ));
  modify($scss_file, sub {s!ccc!ddd!});
  $app->asset('change.css' => '/sass/issue-60.scss');
  like + ($app->asset->get('change.css', {assets => 1}))[0]->slurp, qr{\#ddd},
    'SASS_PATH is searched after dirname($path)';
  is int(split ':', $ENV{SASS_PATH}), 3, 'SASS_PATH was localized';

  # include_paths()
  $app = t::Helper->t_old->app;
  modify($scss_file, sub {s!ddd!333!});
  $app->asset->preprocessors->add(scss => Scss => {include_paths => [split /:/, $ENV{SASS_PATH}]});
  local $ENV{SASS_PATH} = '';
  $app->asset('change.css' => '/sass/issue-60.scss');
  like + ($app->asset->get('change.css', {assets => 1}))[0]->slurp, qr{\#333},
    'include_paths() is searched after dirname($path)';
  is int(split ':', $ENV{SASS_PATH}), 0, 'SASS_PATH was localized';

  # reset
  modify($scss_file, sub {s!333!ccc!});
}

{
  # https://github.com/jhthorsen/mojolicious-plugin-assetpack/pull/62

  my $scss_file = File::Spec->catfile(qw( t public sass issue-62-import.scss ));
  my $app       = t::Helper->t_old->app;
  $app->asset('change.css' => '/sass/issue-62.scss');
  like + ($app->asset->get('change.css', {assets => 1}))[0]->slurp, qr{\#ccc}, 'original';

  modify($scss_file, sub {s!ccc!ddd!});
  $app = t::Helper->t_old->app;
  $app->asset('change.css' => '/sass/issue-62.scss');
  like + ($app->asset->get('change.css', {assets => 1}))[0]->slurp, qr{\#ddd}, 'updated';

  modify($scss_file, sub {s!ddd!ccc!});
}

{
  my @warn;
  local $ENV{SASS_PATH} = undef;
  local $SIG{__WARN__} = sub { push @warn, $_[0] };
  Mojolicious::Plugin::AssetPack::Preprocessor::Scss->new->_include_paths(Cwd::getcwd);
  is "@warn", "", "No uninitialized value warning";
}

done_testing;

sub modify {
  use Mojo::Util qw( slurp spurt );
  my ($scss_file, $cb) = @_;
  local $_ = slurp $scss_file;
  $cb->();
  spurt $_ => $scss_file;
}

__DATA__
@@ test1.html.ep
%= asset 'scss.css'
@@ x.html.ep
%= asset 'x.css'
@@ include-dir.html.ep
%= asset 'include-dir.css'
