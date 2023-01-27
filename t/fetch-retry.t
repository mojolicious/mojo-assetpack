use lib '.';
use t::Helper;

use Mojo::IOLoop;
use Mojo::Server::Daemon;
use Mojolicious;

my $t = t::Helper->t(pipes => [qw(Css Fetch)]);

my $app = Mojolicious->new;
$app->config->{attempts} = 0;
$app->routes->get(
  '/test.css' => sub {
    my $c = shift;
    return $c->render(data => 'Internal server error', status => 500) if $c->app->config->{attempts}++ <= 2;
    $c->render(data => 'body { color: #00f }');
  }
);
my $responses = [];
$app->hook(
  before_dispatch => sub {
    shift->on(finish => sub { push @$responses, shift->res->code });
  }
);
my $daemon = Mojo::Server::Daemon->new(listen => ['http://*'], ioloop => $t->app->asset->ua->ioloop, app => $app);
my $port   = $daemon->start->ports->[0];

subtest 'Defaults' => sub {
  is $t->app->asset->store->retries,     0, 'no retries by default';
  is $t->app->asset->store->retry_delay, 3, '3 second retry delay by default';
};

subtest 'Download asset with multiple attempts' => sub {
  $t->app->asset->store->retries(3)->retry_delay(0.1);
  $t->app->asset->process('app.css' => "http://127.0.0.1:$port/test.css");

  $t->get_ok('/')->status_is(200)->content_like(qr{Hello world});
  $t->get_ok($t->tx->res->dom->at('link')->{href})->status_is(200)->content_like(qr{body.+color.+00f});
  is_deeply $responses, [500, 500, 500, 200], 'right responses';
};

done_testing;

__DATA__
@@ index.html.ep
%= asset 'app.css'
Hello world
