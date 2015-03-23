use t::Helper;

{
  my $t = t::Helper->t({minify => 0});

  plan skip_all => 'Could not find preprocessors for jsx' unless $t->app->asset->preprocessors->can_process('jsx');

  $t->app->asset('jsx.js'   => '/js/c.jsx');
  $t->app->asset('error.js' => '/js/error.jsx');

  $t->get_ok('/test1')->status_is(200)->content_like(qr{;[\n\s]+React})
    ->content_like(qr{var app\s*=\s*React\..*div.*{.*"appClass"},\s*"Hello, React!"\)});

  $t->get_ok('/test1')->status_is(200)->content_like(qr{alert\('.*Failed to run})
    ->content_like(qr{console\.log\('.*Failed to run});
}

{
  my $t = t::Helper->t({minify => 1});

  $t->app->asset('jsx.js' => '/js/c.jsx');
  $t->get_ok('/test1')->status_is(200)->content_like(qr{;React});
}

done_testing;

__DATA__
@@ test1.html.ep
%= asset 'jsx.js', { inline => 1 }
%= asset 'error.js', { inline => 1 }
