# NAME

Mojolicious::Plugin::AssetPack - Compress and convert css, less, sass, javascript and coffeescript files

# VERSION

2.08

# SYNOPSIS

## Application

    use Mojolicious::Lite;

    # Load plugin and pipes in the right order
    plugin AssetPack => {
      pipes => [qw(Less Sass Css CoffeeScript Riotjs JavaScript Combine)]
    };

    # define asset
    app->asset->process(
      # virtual name of the asset
      "app.css" => (

        # source files used to create the asset
        "sass/bar.scss",
        "https://github.com/Dogfalo/materialize/blob/master/sass/materialize.scss",
      )
    );

## Template

    <html>
      <head>
        %= asset "app.css"
      </head>
      <body><%= content %></body>
    </html>

# DESCRIPTION

[Mojolicious::Plugin::AssetPack](https://metacpan.org/pod/Mojolicious::Plugin::AssetPack) is [Mojolicious plugin](https://metacpan.org/pod/Mojolicious::Plugin)
for processing static assets. The idea is that JavaScript and CSS files should
be served as one minified file to save bandwidth and roundtrip time to the
server.

Note that the main author have moved on to using
[Mojolicious::Plugin::Webpack](https://metacpan.org/pod/Mojolicious::Plugin::Webpack) instead, which uses
[https://webpack.js.org/](https://webpack.js.org/) under the hood, but is just as convenient to use as
this plugin. It is very easy to try out
[Mojolicious::Plugin::Webpack](https://metacpan.org/pod/Mojolicious::Plugin::Webpack), since it will detect your AssetPack
based project automatically, and migrate them over to webpack once the plugin
is loaded.

There are many external tools for doing this, but integrating them with
[Mojolicious](https://metacpan.org/pod/Mojolicious) can be a struggle: You want to serve the source files directly
while developing, but a minified version in production. This assetpack plugin
will handle all of that automatically for you.

Your application creates and refers to an asset by its topic (virtual asset
name).  The process of building actual assets from their components is
delegated to "pipe objects". Please see
["Pipes" in Mojolicious::Plugin::AssetPack::Guides::Tutorial](https://metacpan.org/pod/Mojolicious::Plugin::AssetPack::Guides::Tutorial#Pipes) for a complete list.

# BREAKING CHANGES

## assetpack.db (v1.47)

`assetpack.db` no longer track files downloaded from the internet. It will
mostly "just work", but in some cases version 1.47 might download assets that
have already been downloaded with AssetPack version 1.46 and earlier.

The goal is to remove `assetpack.db` completely.

# GUIDES

- [Mojolicious::Plugin::AssetPack::Guides::Tutorial](https://metacpan.org/pod/Mojolicious::Plugin::AssetPack::Guides::Tutorial)

    The tutorial will give an introduction to how AssetPack can be used.

- [Mojolicious::Plugin::AssetPack::Guides::Developing](https://metacpan.org/pod/Mojolicious::Plugin::AssetPack::Guides::Developing)

    The "developing" guide will give insight on how to do effective development with
    AssetPack and more details about the internals in this plugin.

- [Mojolicious::Plugin::AssetPack::Guides::Cookbook](https://metacpan.org/pod/Mojolicious::Plugin::AssetPack::Guides::Cookbook)

    The cookbook has various receipes on how to cook with AssetPack.

# HELPERS

## asset

    $self = $app->asset;
    $self = $c->asset;
    $bytestream = $c->asset($topic, @args);
    $bytestream = $c->asset("app.css", media => "print");

`asset()` is the main entry point to this plugin. It can either be used to
access the [Mojolicious::Plugin::AssetPack](https://metacpan.org/pod/Mojolicious::Plugin::AssetPack) instance or as a tag helper.

The helper name "asset" can be customized by specifying "helper" when
[registering](#register) the plugin.

See [Mojolicious::Plugin::AssetPack::Guides::Tutorial](https://metacpan.org/pod/Mojolicious::Plugin::AssetPack::Guides::Tutorial) for more details.

# ATTRIBUTES

## minify

    $bool = $self->minify;
    $self = $self->minify($bool);

Set this to true to combine and minify the assets. Defaults to false if
["mode" in Mojolicious](https://metacpan.org/pod/Mojolicious#mode) is "development" and true otherwise.

See ["Application mode" in Mojolicious::Plugin::AssetPack::Guides::Tutorial](https://metacpan.org/pod/Mojolicious::Plugin::AssetPack::Guides::Tutorial#Application-mode)
for more details.

## route

    $route = $self->route;
    $self = $self->route($route);

A [Mojolicious::Routes::Route](https://metacpan.org/pod/Mojolicious::Routes::Route) object used to serve assets. The default route
responds to HEAD and GET requests and calls
[serve\_asset()](https://metacpan.org/pod/Mojolicious::Plugin::AssetPack::Store#serve_asset) on ["store"](#store)
to serve the asset.

The default route will be built and added to the [application](https://metacpan.org/pod/Mojolicious)
when ["process"](#process) is called the first time.

See ["ASSETS FROM CUSTOM DOMAIN" in Mojolicious::Plugin::AssetPack::Guides::Cookbook](https://metacpan.org/pod/Mojolicious::Plugin::AssetPack::Guides::Cookbook#ASSETS-FROM-CUSTOM-DOMAIN)
for an example on how to customize this route.

## store

    $obj = $self->store;
    $self = $self->store(Mojolicious::Plugin::AssetPack::Store->new);

Holds a [Mojolicious::Plugin::AssetPack::Store](https://metacpan.org/pod/Mojolicious::Plugin::AssetPack::Store) object used to locate, store
and serve assets.

## tag\_for

Deprecated. Use ["renderer" in Mojolicious::Plugin::AssetPack::Asset](https://metacpan.org/pod/Mojolicious::Plugin::AssetPack::Asset#renderer) instead.

## ua

    $ua = $self->ua;

Holds a [Mojo::UserAgent](https://metacpan.org/pod/Mojo::UserAgent) which can be used to fetch assets either from local
application or from remote web servers.

# METHODS

## pipe

    $obj = $self->pipe($name);
    $obj = $self->pipe("Css");

Will return a registered pipe by `$name` or `undef` if none could be found.

## process

    $self = $self->process($topic => @assets);
    $self = $self->process($definition_file);

Used to process assets. A `$definition_file` can be used to define `$topic`
and `@assets` in a separate file. See
["Process assets" in Mojolicious::Plugin::AssetPack::Guides::Tutorial](https://metacpan.org/pod/Mojolicious::Plugin::AssetPack::Guides::Tutorial#Process-assets) for more
details.

`$definition_file` defaults to "assetpack.def".

## processed

    $collection = $self->processed($topic);

Can be used to retrieve a [Mojo::Collection](https://metacpan.org/pod/Mojo::Collection) object, with zero or more
[Mojolicious::Plugin::AssetPack::Asset](https://metacpan.org/pod/Mojolicious::Plugin::AssetPack::Asset) objects. Returns undef if `$topic` is
not defined with ["process"](#process).

## register

    $self->register($app, \%config);

Used to register the plugin in the application. `%config` can contain:

- helper

    Name of the helper to add to the application. Default is "asset".

- pipes

    This argument is mandatory and need to contain a complete list of pipes that is
    needed. Example:

        $app->plugin(AssetPack => {pipes => [qw(Sass Css Combine)]);

    See ["Pipes" in Mojolicious::Plugin::AssetPack::Guides::Tutorial](https://metacpan.org/pod/Mojolicious::Plugin::AssetPack::Guides::Tutorial#Pipes) for a complete
    list of available pipes.

- proxy

    A hash of proxy settings. Set this to `0` to disable proxy detection.
    Currently only "no\_proxy" is supported, which will set which requests that
    should bypass the proxy (if any proxy is detected). Default is to bypass all
    requests to localhost.

    See ["detect" in Mojo::UserAgent::Proxy](https://metacpan.org/pod/Mojo::UserAgent::Proxy#detect) for more information.

# SEE ALSO

[Mojolicious::Plugin::Webpack](https://metacpan.org/pod/Mojolicious::Plugin::Webpack).

["GUIDES"](#guides),
[Mojolicious::Plugin::AssetPack::Asset](https://metacpan.org/pod/Mojolicious::Plugin::AssetPack::Asset),
[Mojolicious::Plugin::AssetPack::Pipe](https://metacpan.org/pod/Mojolicious::Plugin::AssetPack::Pipe) and
[Mojolicious::Plugin::AssetPack::Store](https://metacpan.org/pod/Mojolicious::Plugin::AssetPack::Store).

# COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

# AUTHOR

Jan Henning Thorsen - `jhthorsen@cpan.org`

Alexander Rymasheusky

Mark Grimes - `mgrimes@cpan.org`

Per Edin - `info@peredin.com`

Viktor Turskyi
