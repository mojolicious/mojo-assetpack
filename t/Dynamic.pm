package t::Dynamic;
use Mojo::Base 'Mojolicious';
use Test::More;

sub startup {
  my $app = shift;
  my $r   = $app->routes;

  $app->mode('production');
  $app->plugin('AssetPack');
  $app->plugin(Config => {default => {bg_color => 'blue'}});

  $r->get('/test.css')->to(
    cb => sub {
      my $c = shift;
      $c->render(text => 'body { background-color: ' . $c->config('bg_color') . ' }', format => 'css');
    }
  )->name('mystyle');

  $r->get('/inline')->to(
    cb => sub {
      shift->render(inline => '%= asset "myapp.css", { inline => 1 }');
    }
  )->name('inline');

  $r->get('/referred')->to(
    cb => sub {
      shift->render(inline => q(<html><head><%= asset "myapp.css", {inline => 1} %></head></html>));
    }
  )->name('referred');

  # Start event loop if necessary
  $app->asset('myapp.css' => $app->url_for('mystyle'));
}

1;
