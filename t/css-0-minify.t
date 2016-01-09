use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use Mojolicious::Lite;

plugin 'assetpipe';

app->asset->process('app.css' => ('/css/one.css', '/css/two.css'));
my $tags = app->asset('app.css');

like $tags, qr{^<link.*src="/asset/0123456789/one.css"}, 'link one';
like $tags, qr{^<link.*src="/asset/0123456789/two.css"}, 'link two';

done_testing;
