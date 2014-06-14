use t::Helper;

my $i;

{
  $i = 42;

  my $t = add_preprocessor(t::Helper->t({ minify => 0 }));
  my @files;

  diag "minify=0 MOJO_ASSETPACK_NO_CACHE=0";
  local $ENV{MOJO_ASSETPACK_NO_CACHE} = 0;
  $t->get_ok('/no-cache');
  push @files, $t->tx->res->dom->at('script')->{src};
  $t->get_ok($files[-1])->status_is(200)->content_like(qr{var i = 42;}, 'var i = 42');

  $i = 40;
  $t->get_ok('/no-cache');
  push @files, $t->tx->res->dom->at('script')->{src};
  $t->get_ok($files[-1])->status_is(200)->content_like(qr{var i = 42;}, 'minify=0 MOJO_ASSETPACK_NO_CACHE=0');

  diag "minify=0 MOJO_ASSETPACK_NO_CACHE=1";
  local $ENV{MOJO_ASSETPACK_NO_CACHE} = 1;
  $t->get_ok('/no-cache');
  push @files, $t->tx->res->dom->at('script')->{src};
  $t->get_ok($files[-1])->status_is(200)->content_like(qr{var i = 40;}, 'var i = 40');

  $i = 61;
  $t->get_ok('/no-cache');
  push @files, $t->tx->res->dom->at('script')->{src};
  $t->get_ok($files[-1])->status_is(200)->content_like(qr{var i = 61;}, 'var i = 61');

  for my $file (@files) {
    is $file, $files[0], "$file = $files[0]";
  }
}

{
  $i = 42;

  my $t = add_preprocessor(t::Helper->t({ minify => 1 }));
  my @files;

  diag "minify=1 MOJO_ASSETPACK_NO_CACHE=0";
  local $ENV{MOJO_ASSETPACK_NO_CACHE} = 0;
  $t->get_ok('/no-cache');
  push @files, $t->tx->res->dom->at('script')->{src};
  $t->get_ok($files[-1])->status_is(200)->content_like(qr{var i = 42; // minified}, 'var i = 42');

  $i = 40;
  $t = add_preprocessor(t::Helper->t({ minify => 1 }));
  $t->get_ok('/no-cache');
  push @files, $t->tx->res->dom->at('script')->{src};
  $t->get_ok($files[-1])->status_is(200)->content_like(qr{var i = 42; // minified}, 'minify=1 MOJO_ASSETPACK_NO_CACHE=0');

  diag "minify=1 MOJO_ASSETPACK_NO_CACHE=1";
  local $ENV{MOJO_ASSETPACK_NO_CACHE} = 1;
  $t = add_preprocessor(t::Helper->t({ minify => 1 }));
  $t->get_ok('/no-cache');
  push @files, $t->tx->res->dom->at('script')->{src};
  $t->get_ok($files[-1])->status_is(200)->content_like(qr{var i = 40; // minified}, 'var i = 40');

  $i = 61;
  $t = add_preprocessor(t::Helper->t({ minify => 1 }));
  $t->get_ok('/no-cache');
  push @files, $t->tx->res->dom->at('script')->{src};
  $t->get_ok($files[-1])->status_is(200)->content_like(qr{var i = 61; // minified}, 'var i = 61');

  for my $file (@files) {
    is $file, $files[0], "$file = $files[0]";
  }
}

sub add_preprocessor {
  my $t = shift;

  $t->app->asset->preprocessors->remove('coffee');
  $t->app->asset->preprocessors->map_type(coffee => 'js');
  $t->app->asset->preprocessors->add(coffee => sub {
    my($assetpack, $text, $file) = @_;
    $$text = "var i = $i;";
    $$text .= " // minified" if $assetpack->minify;
  });

  $t->app->asset('app.js' => '/js/c.coffee');

  $t;
}

done_testing;

__DATA__
@@ no-cache.html.ep
%= asset 'app.js'
