use t::Helper;
use File::Basename 'basename';
use File::Spec::Functions 'catfile';

my @assets;

{
  my $t = t::Helper->t({minify => 1});
  my $out_dir = $t->app->asset->out_dir;
  $t->app->asset('app.css' => '/css/c.css', '/css/d.css');
  $t->app->asset('foo.css' => '/css/d.css', '/css/c.css');
  @assets = map { catfile $out_dir, basename($_) } map {@$_} values %{$t->app->asset->{processed}};
  ok @assets, 'created assets';
  ok -e ($_), "created $_" for @assets;
}

{
  my $t = t::Helper->t({minify => 1});
  my @unlink;
  eval { $t->app->asset->purge };
  like $@, qr{AFTER}, 'need to define assets before calling purge';
  $t->app->asset('rename.css' => '/css/1w.css');
  $t->app->asset->purge;
  ok !-e $_, "purged $_" for @assets;
}

done_testing;
