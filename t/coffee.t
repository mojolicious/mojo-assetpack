use t::Helper;

{
  diag "minify=0";
  my $t = t::Helper->t({ minify => 0 });

  plan skip_all => 'Could not find preprocessors for coffee', 6 unless $t->app->asset->preprocessors->can_process('coffee');

  $t->app->asset('coffee.js' => '/js/c.coffee', '/js/d.coffee');

  $t->get_ok('/coffee')
    ->status_is(200)
    ->content_like(qr{<script \s src="/packed/c-\w+\.js"
                      .*
                      <script \s src="/packed/d-\w+\.js"
                  }sx);

  $t->get_ok($t->tx->res->dom->at('script')->{src})
    ->status_is(200)
    ->content_like(qr{console\.log\(['"]hello from c coffee});
}

{
  diag "minify=1";
  my $t = t::Helper->t({ minify => 1 });

  $t->app->asset('coffee.js' => '/js/c.coffee', '/js/d.coffee');

  $t->get_ok('/coffee')
    ->status_is(200)
    ->content_like(qr{<script src="/packed/coffee-\w+\.js".*}m)
    ;

  $t->get_ok($t->tx->res->dom->at('script')->{src})
    ->status_is(200)
    ->content_like(qr{c coffee.*d coffee})
    ;
}

done_testing;

__DATA__
@@ coffee.html.ep
%= asset 'coffee.js'
