BEGIN { $ENV{MOJO_ASSETPACK_NO_CACHE} = 1 }
use t::Helper;

my $i;

{
  my $t = add_preprocessor(t::Helper->t({minify => 0}));
  my @files;

  $i = 42;
  $t->get_ok('/test1');
  push @files, $t->tx->res->dom->at('script')->{src};
  $t->get_ok($files[-1])->status_is(200)->content_like(qr{var i = 42;}, 'var i = 40');

  $i = 60;
  $t->get_ok('/test1');
  push @files, $t->tx->res->dom->at('script')->{src};
  $t->get_ok($files[-1])->status_is(200)->content_like(qr{var i = 60;}, 'var i = 61');

  for my $file (@files) {
    is $file, $files[0], "$file = $files[0]";
  }
}

{
  my $t = add_preprocessor(t::Helper->t({minify => 1}));
  my @files;

  $i = 40;
  $t->get_ok('/test1');
  push @files, $t->tx->res->dom->at('script')->{src};
  $t->get_ok($files[-1])->status_is(200)->content_like(qr{var i = 40; // minified}, 'var i = 40');

  $i = 61;
  $t->get_ok('/test1');
  push @files, $t->tx->res->dom->at('script')->{src};
  $t->get_ok($files[-1])->status_is(200)->content_like(qr{var i = 61; // minified}, 'var i = 61');

  for my $file (@files) {
    is $file, $files[0], "$file = $files[0]";
  }
}

sub add_preprocessor {
  my $t = shift;

  $t->app->asset->preprocessors->remove('coffee');
  $t->app->asset->preprocessors->add(
    coffee => sub {
      my ($assetpack, $text, $file) = @_;
      $$text = "var i = $i;";
      $$text .= " // minified" if $assetpack->minify;
    }
  );

  $t->app->asset('app.js' => '/js/c.coffee');

  $t;
}

done_testing;

__DATA__
@@ test1.html.ep
%= asset 'app.js'
