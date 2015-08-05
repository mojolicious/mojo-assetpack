use t::Helper;
no warnings 'redefine';

{
  my $t = t::Helper->t({minify => 1});
  $t->app->asset('app.css' => '/css/c.css', '/css/d.css');
  $t->app->asset('foo.css' => '/css/d.css', '/css/c.css');
}

{
  my $t = t::Helper->t({minify => 1});
  my @unlink;
  *Mojolicious::Plugin::AssetPack::_unlink_packed = sub { push @unlink, $_[1] };
  eval { $t->app->asset->purge };
  like $@, qr{AFTER}, 'need to define assets before calling purge';
  $t->app->asset('rename.css' => '/css/1w.css');
  $t->app->asset->purge;
  is_deeply(
    [sort @unlink],
    [qw( app-3659f2c6b80de93f8373568a1ddeffaa.min.css foo-0cbacb97f7b3f70fb6d39926d48dba68.min.css )],
    'unlinked old packed files'
    )
}

done_testing;
