BEGIN { $ENV{MOJO_MODE} = 'not_development' }
use t::Helper;
use Mojo::Loader 'data_section';
use Mojolicious::Plugin::AssetPack::Util 'checksum';

$ENV{MOJO_ASSETPACK_CLEANUP} = 0;

# simulate minify()
no warnings qw(once redefine);
eval 'require CSS::Minifier::XS;1';
*CSS::Minifier::XS::minify = sub { local $_ = shift; s!\s+!!g; $_ };

my $t             = t::Helper->t(pipes => [qw(Css Combine)]);
my @assets        = qw(one.css recreate.css);
my $recreate_path = File::Spec->catfile(qw(t assets recreate.css));

Mojo::Util::spurt ".recreate { color: #aaa }\n" => $recreate_path;
$t->app->asset->process('app.css' => @assets);

$t->get_ok('/')->status_is(200)->element_exists(qq(link[href\$="/app.css"]));
my $link = $t->tx->res->dom->at('link')->{href};

# use cached
$t = t::Helper->t(pipes => [qw(Css Combine)]);
$t->app->asset->process('app.css' => @assets);
$t->get_ok('/')->status_is(200);
is $t->tx->res->dom->at('link')->{href}, $link, 'same link href';

# recreate
Mojo::Util::spurt ".recreate { color: #bbb }\n" => $recreate_path;
my $tr = t::Helper->t(pipes => [qw(Css Combine)]);
$tr->app->asset->process('app.css' => @assets);
$tr->get_ok('/')->status_is(200);
isnt $tr->tx->res->dom->at('link')->{href}, $link, 'changed link href';
$tr->get_ok($tr->tx->res->dom->at('link')->{href})->status_is(200)
  ->content_like(qr{color:\#bbb});

# reset asset
Mojo::Util::spurt ".recreate { color: #aaa }\n" => $recreate_path;
$ENV{MOJO_ASSETPACK_CLEANUP} = 1;

done_testing;
__DATA__
@@ index.html.ep
%= asset 'app.css'
@@ one.css
.one { color: #aaa }
