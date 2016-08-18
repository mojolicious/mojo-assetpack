use t::Helper;

$ENV{MOJO_MODE} = 'development';
t()->content_like(qr{development})->content_unlike(qr{foo});

$ENV{MOJO_MODE} = 'production';
t()->content_like(qr{foo})->content_like(qr{production});

$ENV{MOJO_MODE} = 'foo';
t()->content_like(qr{foo})->content_unlike(qr{production});

done_testing;

sub t {
  my $t = t::Helper->t(pipes => [qw(Css Combine)]);
  $t->app->asset->minify(0);
  $t->app->asset->pipe('Combine')->enabled(1);
  $t->app->asset->process;
  $t->get_ok('/')->status_is(200);
  $t->get_ok($t->tx->res->dom->at('link')->{href})->status_is(200);
}

__DATA__
@@ index.html.ep
%= asset 'app.css'
@@ assetpack.def
# there should be a whitespace after "! app.css"
# https://github.com/jhthorsen/mojolicious-plugin-assetpack/issues/93
! app.css 
< development.css [mode==development] [minify==0]
< production.css  [mode=production]
< foo.css         [mode!=development]
@@ development.css
.development { color: #222 }
@@ foo.css
.foo { color: #333 }
@@ production.css
.production { color: #444 }
