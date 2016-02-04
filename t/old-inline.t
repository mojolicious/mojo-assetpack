use t::Helper;

{
  my $t = t::Helper->t_old({minify => 0});

  $t->app->asset('app.css' => '/css/a.css', '/css/b.css');

  # inlined
  $t->get_ok('/test1')->status_is(200)->text_like('style', qr{background: \#a1a1a1;.*background: \#b1b1b1;}s);

  # still available as files
  $t->get_ok('/packed/a-09a653553edca03ad3308a868e5a06ac.css')->content_like(qr{a1a1a1;});
}

{
  my $t = t::Helper->t_old({minify => 1});

  $t->app->asset('app.css' => '/css/a.css', '/css/b.css');

  # inlined and minified
  $t->get_ok('/test1')->status_is(200)->text_like('style', qr{background:\#a1a1a1.*background:\#b1b1b1}s);
}

SKIP: {
  my $t = t::Helper->t_old({minify => 1});
  skip 'sass required', 3 unless $t->app->asset->preprocessors->can_process('scss');

  $t->app->routes->get('/inline-sass')->to(template => 'inline_sass');
  $t->app->asset('app.css' => '/sass/y.scss', '/sass/x.scss');

  # inlined and minified
  $t->get_ok('/inline-sass')->status_is(200)->text_like('style', qr{text-decoration:underline.*background:\#abcdef}s);
}


done_testing;

__DATA__
@@ test1.html.ep
%= asset 'app.css', { inline => 1 }
@@ inline_sass.html.ep
%= asset 'app.css', { inline => 1 }
