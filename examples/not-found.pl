#!/usr/bin/env perl
die "Run $0 from ./mojo-assetpack/ root" unless -d 't/assets';
use lib 'lib';
use Mojolicious::Lite;

plugin 'AssetPack' => {pipes => [qw(Css JavaScript)]};
app->asset->store->paths(['t/assets']);

app->asset->process('app.css' => 'css/c.css');
app->asset->process('app.js'  => 'js/not-found.js');

# Set up the mojo lite application and start it
get '/' => 'index';
app->start;

__DATA__
@@ index.html.ep
<html>
<head>
  <title>Test!</title>
  <link rel="stylesheet" href="/asset/fallback/app.css">
</head>
<body>
  <h1>Check the console for debug messages</h1>
  <p>And the background should be gray.</p>
  <script src="/asset/fallback/app.js"></script>
</body>
</html>
