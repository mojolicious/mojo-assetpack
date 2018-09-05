#!/usr/bin/env perl
die "Run $0 from ./mojolicious-plugin-assetpack/ root" unless -d 't/assets';
use lib 'lib';
use Mojolicious::Lite;
use Mojo::File 'path';

plugin 'AssetPack' => {pipes => ['RollupJs']};
app->asset->store->paths([path('t/assets')->to_abs]);

# Add Vuejs as dependencies
app->asset->pipe('RollupJs')->add_global(vue => 'Vue');
push @{app->asset->pipe('RollupJs')->modules}, 'vue-template-compiler';
push @{app->asset->pipe('RollupJs')->plugins}, ['rollup-plugin-vue', 'vue'];

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
