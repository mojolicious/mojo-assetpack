use t::Helper;

my @mtime;

{
  my $t = t::Helper->t({source_paths => ['assets']});
  $t->app->asset('app.css' => '/css/c.css');
  $t->get_ok('/test1')->status_is(200)->content_like(qr{c1c1c1});
  @mtime = mtime($t);
  $mtime[1] -= 2;
  utime $mtime[1], reverse @mtime;
}

{
  my $t = t::Helper->t({source_paths => [Cwd::abs_path(File::Spec->catdir(File::Basename::dirname($0), 'assets'))]});
  $t->app->asset('app.css' => '/css/c.css');
  $t->get_ok('/test1')->status_is(200)->content_like(qr{c1c1c1});

  # make sure we find packed assets in public directories
  is_deeply [mtime($t)], \@mtime, 'same packed file';
}

done_testing;

sub mtime {
  map { ($_->path, (stat $_->path)[9]) } $_[0]->app->asset->get('app.css', {assets => 1});
}

__DATA__
@@ test1.html.ep
%= asset 'app.css', {inline => 1}
