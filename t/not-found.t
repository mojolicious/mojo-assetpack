use lib '.';
use t::Helper;

my $t = t::Helper->t(pipes => [qw(Css Combine)]);
eval { $t->app->asset->process };
like $@, qr{Could not find input asset "no-such-stylesheet\.css"}, 'could not find asset';

$t->app->asset->process('something.png', 'image/sample.png');
$t->app->asset->process('app.css',       'input.css');

$t->get_ok('/')->status_is(200)
  ->element_exists(qq(link[href="/asset/f956a3f925/input.css"]));

# Valid request
$t->get_ok('/asset/f956a3f925/input.css')->status_is(200);

# TODO: /:name is ignored. This might need to change
$t->get_ok('/asset/f956a3f925/foo.css')->status_is(200);

# This is useful when assets are combined
$t->get_ok('/asset/aaaaaaaaaa/app.css')->status_is(200)
  ->content_is(qq(\@import "/asset/f956a3f925/input.css";\n));

# Both checksum and topic is invalid
$t->get_ok('/asset/aaaaaaaaaa/foo.css')->status_is(404)
  ->content_is("// No such asset 'foo.css'\n");

$t->get_ok('/asset/aaaaaaaaaa/something.png')->status_is(302)
  ->header_like(Location => qr{^/asset/\w+/something.png$});
$t->get_ok($t->tx->res->headers->location)->status_is(200);

done_testing;

__DATA__
@@ assetpack.def
! app.css
< no-such-stylesheet.css
@@ index.html.ep
%= asset 'app.css'
@@ input.css
.one { color: #111; }
