#!/usr/bin/env perl
use Mojolicious::Lite;

# need to specify to AssetPack that we want to enable "reloader"
plugin AssetPack => {reloader => {}};

# define our own assets, define some routes and start the app
app->asset("app.css" => "/css/app.css");
get "/" => "index";
app->start;

__DATA__
@@ css/app.css
body { background: #eee; }
@@ index.html.ep
<!DOCTYPE html>
<html>
  <head>
    <title>Reloader demo</title>
    %= asset "app.css"
    %# Reloader is only available in development mode
    %= asset "reloader.js" if app->mode eq "development"
  </head>
  <body>
    Reloader demo. Try to change css/app.css and see this page auto-update.
  </body>
</html>
