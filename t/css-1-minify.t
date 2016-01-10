BEGIN { $ENV{MOJO_MODE} = 'not_development' }
use Mojo::Base -strict;
use Mojo::Loader 'data_section';
use Mojolicious::Plugin::Assetpipe::Util 'checksum';
use Test::Mojo;
use Test::More;

my @assets = qw( d/one.css d/two.css d/already-min.css );
my $checksum = checksum join ':', map { checksum(data_section __PACKAGE__, $_) } @assets;

use Mojolicious::Lite;
get '/' => 'index';
plugin 'assetpipe';
app->asset->process('app.css' => @assets);

my $file = app->asset->static->file('cache/one-f956a3f925.min.css');
ok $file, 'cache one';

my $t = Test::Mojo->new;

$t->get_ok('/')->status_is(200)
  ->element_exists(qq(link[href="/asset/$checksum/app.css"]));

$t->get_ok("/asset/$checksum/app.css")->status_is(200)
  ->content_like(qr/\.one\{color.*\.two\{color.*.skipped\s\{/s);

done_testing;

__DATA__
@@ index.html.ep
%= asset 'app.css'
@@ d/one.css
.one { color: #111; }
@@ d/two.css
.two { color: #222; }
@@ d/already-min.css
.skipped { color: #222; }
