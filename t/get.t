use t::Helper;

{
  my $t = t::Helper->t({minify => 0});
  my @data;

  $t->app->asset('app.css' => '/css/a.css', '/css/b.css');

  is_deeply([$t->app->asset->get('app.css')],
    [qw( /packed/a-09a653553edca03ad3308a868e5a06ac.css /packed/b-89dbc5a64c4e7e64a3d1ce177b740a7e.css )], 'get()');

  @data = $t->app->asset->get('app.css', {inline => 1});
  like $data[0], qr{background:\s*\#a1a1a1}, 'a.css';
  like $data[1], qr{background:\s*\#b1b1b1}, 'b.css';
}

done_testing;

__DATA__
@@ css.html.ep
%= asset 'app.css'
