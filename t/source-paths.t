use t::Helper;

{
  my $t = t::Helper->t({source_paths => ['assets']});

  $t->app->static->paths([]);
  $t->app->asset('app.css' => '/css/c.css', '/css/d.css');
  $t->get_ok('/test1')->status_is(200)->content_like(qr{c1c1c1.*d1d1d1}s);
}

{
  my $t = t::Helper->t({source_paths => [Cwd::abs_path(File::Spec->catdir(File::Basename::dirname($0), 'assets'))]});

  $t->app->static->paths([]);
  $t->app->asset('app.css' => '/css/c.css', '/css/d.css');
  $t->get_ok('/test1')->status_is(200)->content_like(qr{c1c1c1.*d1d1d1}s);
}

done_testing;

__DATA__
@@ test1.html.ep
%= asset 'app.css', {inline => 1}
