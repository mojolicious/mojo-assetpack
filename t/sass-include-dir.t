use warnings;
use strict;
use Test::More;
use Test::Mojo;

unlink glob 't/public/packed/*';

my $assetpack;

{
  use Mojolicious::Lite;
  plugin 'AssetPack';

  app->asset('foo.css' => '/sass/y.scss');
  $assetpack = app->asset;

  get '/foo' => 'foo';
}

my $t = Test::Mojo->new;

SKIP: {
  skip 'Could not find preprocessors for scss', 1 unless $assetpack->preprocessors->has_subscribers('scss');

  $t->get_ok('/foo')
    ->content_like(qr{<link href="/packed/y-9a1f9477380119f8c2b78e49a38fa227\.css".*}m)
    ->status_is(200)
    ;
}

done_testing;
__DATA__
@@ foo.html.ep
%= asset 'foo.css'
