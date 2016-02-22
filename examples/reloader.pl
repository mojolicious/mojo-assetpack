#!/usr/bin/env perl
use lib 'lib';
use Mojolicious::Lite;

# 1) Run: perl examples/reloader.pl daemon --listen http://*:3000
# 2) Open your browser at http://localhost:3000
# 3) Change the background color in t/assets/example.css and
#    see the change in the browser instantly. Note that this
#    happens without the help from "morbo".

plugin AssetPack => {pipes => ['Reloader']};
app->asset->store->paths(['t/assets']);
app->asset->process('main.css' => 'example.css');

get '/' => 'index';
app->start;

__DATA__
@@ index.html.ep
<!DOCTYPE html>
<html>
<head>
  %= asset 'main.css'
  %= asset 'reloader.js' if app->mode eq 'development'
</head>
<body>
mode=<%= app->mode %>.
<br>time=<%= time %>.
</body>
</html>
