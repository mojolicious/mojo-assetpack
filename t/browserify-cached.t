BEGIN { $ENV{MOJO_ASSETPACK_NO_CACHE} = 1 }
use t::Helper;
use Mojolicious::Plugin::AssetPack::Preprocessor::Browserify;

my $p = Mojolicious::Plugin::AssetPack::Preprocessor::Browserify->new;

plan skip_all => 'npm install module-deps' unless eval { $p->_install_node_module('module-deps') };

my $t = t::Helper->t({});
ok !$t->app->asset->minify, 'not minify';
$t->app->asset->preprocessor(Browserify => {environment => 'development', extensions => ['js']});

my $js_file = File::Spec->catdir(qw( t public js ctrl generated.js ));
my $js      = Mojo::Util::slurp(File::Spec->catdir(qw( t public js ctrl user.js )));
Mojo::Util::spurt($js => $js_file);
utime time, 1421563000, $js_file;    # make sure the file will be marked as changed

$t->app->asset('app.js' => '/js/cache.js');
$t->get_ok('/test1')->status_is(200)->content_like(qr{require\('\.\./robot'\), 'foo'});

$js =~ s!'foo'!'modified'!g;
Mojo::Util::spurt($js, $js_file);
$t->get_ok('/test1')->status_is(200)->content_like(qr{require\('\.\./robot'\), 'modified'});

unlink $js_file;

done_testing;

__DATA__
@@ test1.html.ep
%= asset "app.js" => {inline => 1}
