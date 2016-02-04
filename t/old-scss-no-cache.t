BEGIN { $ENV{MOJO_ASSETPACK_NO_CACHE} = 1 }
use t::Helper;
use Mojo::Util 'spurt';

my $file;
my $t = t::Helper->t_old({minify => 0});

plan skip_all => 'Could not find preprocessors for scss' unless $t->app->asset->preprocessors->can_process('scss');

$file = File::Spec->catfile($t->app->static->paths->[0], 'sass', 'no-cache.scss');
$t->app->asset('no-cache.css' => '/sass/no-cache.scss');

spurt('@import "x.scss";', $file);
$t->get_ok('/test1')->status_is(200)->content_like(qr{\#abcdef});

spurt('@import "y.scss";', $file);
$t->get_ok('/test1')->status_is(200)->content_like(qr{underline});

END { unlink $file }

done_testing;

__DATA__
@@ test1.html.ep
%= asset 'no-cache.css', {inline => 1}
