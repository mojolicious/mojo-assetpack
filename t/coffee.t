use t::Helper;

{
  my $t = t::Helper->t({minify => 0});

  plan skip_all => 'Could not find preprocessors for coffee'
    unless $t->app->asset->preprocessors->can_process('coffee');

  $t->app->asset('coffee.js' => '/js/c.coffee', '/js/d.coffee');
  $t->get_ok('/test1')->status_is(200)
    ->content_like(qr{<script \s src="/packed/c-\w+\.js" .* <script \s src="/packed/d-\w+\.js" }sx);

  $t->get_ok($t->tx->res->dom->at('script')->{src})->status_is(200)
    ->content_like(qr{console\.log\(['"]hello from c coffee});
}

{
  my $t = t::Helper->t({minify => 1});

  $t->app->asset('coffee.js' => '/js/c.coffee', '/js/d.coffee');
  $t->get_ok('/test1')->status_is(200)->content_like(qr{<script src="/packed/coffee-\w+\.min\.js"}m);
  $t->get_ok($t->tx->res->dom->at('script')->{src})->status_is(200)->content_like(qr{c coffee.*d coffee}s);
}

done_testing;

__DATA__
@@ test1.html.ep
%= asset 'coffee.js'
