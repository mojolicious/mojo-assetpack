#!/usr/bin/env perl
die "Run $0 from ./mojolicious-plugin-assetpack/ root" unless -d 't/assets';
use lib 'lib';
use Mojolicious::Lite;

plugin 'AssetPack' => {pipes => ['RollupJs']};
app->asset->store->paths(['t/assets']);

# Add Vuejs as dependencies
push @{app->asset->pipe('RollupJs')->modules}, 'vue';
unshift @{app->asset->pipe('RollupJs')->plugins}, 'rollup-plugin-vue';

# Process js/vue-app.js
app->asset->process('app.js' => 'js/vue-app.js');

# Set up the mojo lite application and start it
get '/' => 'index';
app->start;

__DATA__
@@ index.html.ep
<html>
<head>
<title>Test!</title>
</head>
<body>
  <div id="app"><my-test x="42"></my-test></div>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/vue/2.4.4/vue.min.js"></script>
  %= asset 'app.js';
</body>
</html>
