#!perl
use lib "lib";
use Mojolicious::Lite;
app->static->paths([Cwd::abs_path("t/public")]);

plugin "AssetPack";
app->asset("my-sprites.css" => "sprites:///images/xyz", "/test.css");

get "/" => "index";
app->start;

__DATA__
@@ test.css
.xyz { background-color: #f00; }
@@ index.html.ep
<html>
  <head>
    <title>Sprites</title>
    %= asset "my-sprites.css"
  </head>
  <body>
    <a href="https://css-tricks.com/css-sprites/">CSS sprites</a>
    <span class="xyz social-github"></span>
    <span class="xyz social-rss"></span>
    <span class="xyz social-chrome"></span>
  </body>
</html>
