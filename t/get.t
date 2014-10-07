use t::Helper;

{
  my $t = t::Helper->t({minify => 0});

  $t->app->asset('app.css' => '/css/a.css', '/css/b.css');

  is_deeply([$t->app->asset->get('app.css')],
    [qw( /packed/a-09a653553edca03ad3308a868e5a06ac.css /packed/b-89dbc5a64c4e7e64a3d1ce177b740a7e.css )], 'get()');
}

done_testing;

__DATA__
@@ css.html.ep
%= asset 'app.css'
