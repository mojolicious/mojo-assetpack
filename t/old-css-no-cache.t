BEGIN { $ENV{MOJO_ASSETPACK_NO_CACHE} = 1 }
use t::Helper;
use Mojo::Util 'spurt';

my $file;

{
  my $t = t::Helper->t_old({minify => 0});
  my @files;

  $file = File::Spec->catfile($t->app->static->paths->[0], 'css', 'no-cache.css');

  $t->app->asset('no-cache.css' => '/css/no-cache.css', '/css/b.css');

  spurt('body { color: #424242; }', $file);
  $t->get_ok('/test1')->status_is(200)->content_like(qr{\#424242});
  push @files, $t->tx->res->dom->at('link')->{href};
  $t->get_ok($files[-1])->status_is(200)->content_like(qr{\#424242});

  spurt('body { color: #606060; }', $file);
  $t->get_ok('/test1')->status_is(200)->content_like(qr{\#606060});
  push @files, $t->tx->res->dom->at('link')->{href};
  $t->get_ok($files[-1])->status_is(200)->header_is('Content-Type', 'text/css')->content_like(qr{\#606060});
  my $mtime = Mojo::Date->new($t->tx->res->headers->last_modified || 0)->epoch;
  ok + ($mtime >= $^T && $mtime < $^T + 10), 'last_modified when application started';
}

{
  my $t = t::Helper->t_old({minify => 1});
  my @files;

  $t->app->asset('no-cache.css' => '/css/no-cache.css', '/css/b.css');

  spurt('body { color: #242424; }', $file);
  $t->get_ok('/test1')->status_is(200)->content_like(qr{\#242424});
  push @files, $t->tx->res->dom->at('link')->{href};
  $t->get_ok($files[-1])->status_is(200)->content_like(qr{\#242424});

  spurt('body { color: #616161; }', $file);
  $t->get_ok('/test1')->status_is(200)->content_like(qr{\#616161});
  my $style = $t->tx->res->dom->at('style');
  ok $style, 'got style tag';
  unlike $style, qr{color:\#616161.*color:\#616161}, 'make sure we do not add_chunk() to the same asset';

  push @files, $t->tx->res->dom->at('link')->{href};
  $t->get_ok($files[-1])->status_is(200)->content_like(qr{\#616161});
}

END { unlink $file }

done_testing;

__DATA__
@@ test1.html.ep
%= asset 'no-cache.css'
%= asset 'no-cache.css', {inline => 1}
