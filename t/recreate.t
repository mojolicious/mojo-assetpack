BEGIN { $ENV{MOJO_MODE} = 'not_development' }
use lib '.';
use t::Helper;
use Mojo::File 'path';
use Mojo::Loader 'data_section';
use Mojolicious::Plugin::AssetPack::Util 'checksum';

# simulate minify()
no warnings 'once';
$INC{'CSS/Minifier/XS.pm'} = 'mocked';
*CSS::Minifier::XS::minify = sub { local $_ = shift; s!\s+!!g; $_ };

my $t        = t::Helper->t(pipes => [qw(Css Combine)]);
my @assets   = qw(one.css recreate.css);
my $recreate = path(qw(t assets recreate.css));

$recreate->spew(".recreate { color: #aaa }\n");

$t->app->asset->process('app.css' => @assets);

$t->get_ok('/')->status_is(200)->element_exists(qq(link[href\$="/app.css"]));
my $link = $t->tx->res->dom->at('link')->{href};

# use cached
$t = t::Helper->t(pipes => [qw(Css Combine)]);
$t->app->asset->process('app.css' => @assets);
$t->get_ok('/')->status_is(200);
is $t->tx->res->dom->at('link')->{href}, $link, 'same link href';

# recreate
$recreate->spew(".recreate { color: #bbb }\n");
my $tr = t::Helper->t(pipes => [qw(Css Combine)]);
$tr->app->asset->process('app.css' => @assets);
$tr->get_ok('/')->status_is(200);
isnt $tr->tx->res->dom->at('link')->{href}, $link, 'changed link href';
$tr->get_ok($tr->tx->res->dom->at('link')->{href})->status_is(200)->content_like(qr{color:\#bbb});

# reset asset
$recreate->spew(".recreate { color: #aaa }\n");

done_testing;
__DATA__
@@ index.html.ep
%= asset 'app.css'
@@ one.css
.one { color: #aaa }
