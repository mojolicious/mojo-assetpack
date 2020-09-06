# NAME

Mojolicious::Plugin::AssetPack - Compress and convert css, less, sass, javascript and coffeescript files

# DESCRIPTION

[Mojolicious::Plugin::AssetPack](https://metacpan.org/pod/Mojolicious%3A%3APlugin%3A%3AAssetPack) has a very limited feature set, especially
when it comes to processing JavaScript. It is recommended that you switch to
[Mojolicious::Plugin::Webpack](https://metacpan.org/pod/Mojolicious%3A%3APlugin%3A%3AWebpack) if you want to write modern JavaScript code.

## Existing user?

It is _very_ simple to migrate from [Mojolicious::Plugin::AssetPack](https://metacpan.org/pod/Mojolicious%3A%3APlugin%3A%3AAssetPack) to
[Mojolicious::Plugin::Webpack](https://metacpan.org/pod/Mojolicious%3A%3APlugin%3A%3AWebpack). Just check out the one line change in
["MIGRATING-FROM-ASSETPACK" in Mojolicious::Plugin::Webpack](https://metacpan.org/pod/Mojolicious%3A%3APlugin%3A%3AWebpack#MIGRATING-FROM-ASSETPACK).

## Don't want to switch?

Your existing code will probably continue to work for a long time, but it will
get more and more difficult to write _new_ working JavaScript with
[Mojolicious::Plugin::AssetPack](https://metacpan.org/pod/Mojolicious%3A%3APlugin%3A%3AAssetPack) as time goes by.

## New user?

Look no further. Just jump over to [Mojolicious::Plugin::Webpack](https://metacpan.org/pod/Mojolicious%3A%3APlugin%3A%3AWebpack).

# HELPERS

## asset

    $self = $app->asset;
    $self = $c->asset;
    $bytestream = $c->asset($topic, @args);
    $bytestream = $c->asset("app.css", media => "print");

`asset()` is the main entry point to this plugin. It can either be used to
access the [Mojolicious::Plugin::AssetPack](https://metacpan.org/pod/Mojolicious%3A%3APlugin%3A%3AAssetPack) instance or as a tag helper.

The helper name "asset" can be customized by specifying "helper" when
[registering](#register) the plugin.

# ATTRIBUTES

## minify

    $bool = $self->minify;
    $self = $self->minify($bool);

Set this to true to combine and minify the assets. Defaults to false if
["mode" in Mojolicious](https://metacpan.org/pod/Mojolicious#mode) is "development" and true otherwise.

## route

    $route = $self->route;
    $self = $self->route($route);

A [Mojolicious::Routes::Route](https://metacpan.org/pod/Mojolicious%3A%3ARoutes%3A%3ARoute) object used to serve assets. The default route
responds to HEAD and GET requests and calls
[serve\_asset()](https://metacpan.org/pod/Mojolicious%3A%3APlugin%3A%3AAssetPack%3A%3AStore#serve_asset) on ["store"](#store)
to serve the asset.

The default route will be built and added to the [application](https://metacpan.org/pod/Mojolicious)
when ["process"](#process) is called the first time.

## store

    $obj = $self->store;
    $self = $self->store(Mojolicious::Plugin::AssetPack::Store->new);

Holds a [Mojolicious::Plugin::AssetPack::Store](https://metacpan.org/pod/Mojolicious%3A%3APlugin%3A%3AAssetPack%3A%3AStore) object used to locate, store
and serve assets.

## tag\_for

Deprecated. Use ["renderer" in Mojolicious::Plugin::AssetPack::Asset](https://metacpan.org/pod/Mojolicious%3A%3APlugin%3A%3AAssetPack%3A%3AAsset#renderer) instead.

## ua

    $ua = $self->ua;

Holds a [Mojo::UserAgent](https://metacpan.org/pod/Mojo%3A%3AUserAgent) which can be used to fetch assets either from local
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
and `@assets` in a separate file.

`$definition_file` defaults to "assetpack.def".

## processed

    $collection = $self->processed($topic);

Can be used to retrieve a [Mojo::Collection](https://metacpan.org/pod/Mojo%3A%3ACollection) object, with zero or more
[Mojolicious::Plugin::AssetPack::Asset](https://metacpan.org/pod/Mojolicious%3A%3APlugin%3A%3AAssetPack%3A%3AAsset) objects. Returns undef if `$topic` is
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

- proxy

    A hash of proxy settings. Set this to `0` to disable proxy detection.
    Currently only "no\_proxy" is supported, which will set which requests that
    should bypass the proxy (if any proxy is detected). Default is to bypass all
    requests to localhost.

    See ["detect" in Mojo::UserAgent::Proxy](https://metacpan.org/pod/Mojo%3A%3AUserAgent%3A%3AProxy#detect) for more information.

# SEE ALSO

[Mojolicious::Plugin::Webpack](https://metacpan.org/pod/Mojolicious%3A%3APlugin%3A%3AWebpack).

# COPYRIGHT AND LICENSE

Copyright (C) 2020, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

# AUTHOR

Jan Henning Thorsen - `jhthorsen@cpan.org`

Alexander Rymasheusky

Mark Grimes - `mgrimes@cpan.org`

Per Edin - `info@peredin.com`

Viktor Turskyi
