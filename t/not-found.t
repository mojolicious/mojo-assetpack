use t::Helper;

my $t = t::Helper->t(pipes => ['Combine']);
eval { $t->app->asset->process };
like $@, qr{Could not find input asset "no-such-stylesheet\.css"}, 'could not find asset';

done_testing;

__DATA__
@@ assetpack.def
! app.css
< no-such-stylesheet.css
