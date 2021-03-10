
# Mojolicious::Plugin::AssetPack [![](https://github.com/mojolicious/mojo-assetpack/workflows/linux/badge.svg)](https://github.com/mojolicious/mojo-assetpack/actions)

  Compress and convert CSS, Less, Sass, JavaScript and CoffeeScript files.

```perl
use Mojolicious::Lite;

# Load plugin and pipes in the right order
plugin AssetPack => {pipes => [qw(Less Sass Css CoffeeScript Riotjs JavaScript Combine)]};

# define asset
app->asset->process(
  # virtual name of the asset
  "app.css" => (

    # source files used to create the asset
    "sass/bar.scss",
    "https://github.com/Dogfalo/materialize/blob/master/sass/materialize.scss",
  )
);
```

## Installation

  All you need is a one-liner, it takes less than a minute.

    $ curl -L https://cpanmin.us | perl - -M https://cpan.metacpan.org -n Mojolicious::Plugin::AssetPack

  We recommend the use of a [Perlbrew](http://perlbrew.pl) environment.
