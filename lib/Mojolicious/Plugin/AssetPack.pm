package Mojolicious::Plugin::AssetPack;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::Util 'trim';
use Mojolicious::Plugin::AssetPack::Asset::Null;
use Mojolicious::Plugin::AssetPack::Store;
use Mojolicious::Plugin::AssetPack::Util qw(diag has_ro load_module DEBUG);

our $VERSION = '1.37';

my %TAG_TEMPLATE;
$TAG_TEMPLATE{css} = [qw(link rel stylesheet href)];
$TAG_TEMPLATE{ico} = [qw(link rel icon href)];
$TAG_TEMPLATE{js}  = [qw(script src)];
$TAG_TEMPLATE{$_} = [qw(img src)]    for qw(gif jpg jpeg png svg);
$TAG_TEMPLATE{$_} = [qw(source src)] for qw(mp3 mp4 ogg ogv webm);

has minify => sub { shift->_app->mode eq 'development' ? 0 : 1 };

has route => sub {
  shift->_app->routes->route('/asset/:checksum/*name')->via(qw(HEAD GET))
    ->name('assetpack')->to(cb => \&_serve);
};

has store => sub {
  my $self = shift;
  Mojolicious::Plugin::AssetPack::Store->new(
    classes => [@{$self->_app->static->classes}],
    paths   => [$self->_app->home->rel_file('assets')],
    ua      => $self->ua,
  );
};

has tag_for => sub {
  my $self = shift;
  my $favicon = $self->pipe('Favicon') ? 1 : 0;

  Scalar::Util::weaken($self);
  return sub {
    my ($asset, $c, $args, @attrs) = @_;
    return $self->pipe('Favicon')->render($c)
      if $args->{topic} eq 'favicon.ico' and $favicon;
    my $url = $asset->url_for($c);
    my @template = @{$TAG_TEMPLATE{$_->format} || $TAG_TEMPLATE{css}};
    splice @template, 1, 0, type => $c->app->types->type($asset->format)
      if $template[0] eq 'source';
    return $c->tag(@template, Mojo::URL->new("$args->{base_url}$url"), @attrs);
  };
};

has_ro ua => sub { Mojo::UserAgent->new->max_redirects(3) };

sub pipe {
  my ($self, $needle) = @_;
  return +(grep { $_ =~ /::$needle\b/ } @{$self->{pipes}})[0];
}

sub process {
  my ($self, $topic, @input) = @_;

  $self->route unless $self->{route_added}++;
  return $self->_process_from_def($topic) unless @input;

  # TODO: The idea with blessed($_) is that maybe the user can pass inn
  # Mojolicious::Plugin::AssetPack::Sprites object, with images to generate
  # CSS from?
  my $assets = Mojo::Collection->new;
  for my $url (@input) {
    my $asset = Scalar::Util::blessed($url) ? $url : $self->store->asset($url);
    die qq(Could not find input asset "$url".) unless Scalar::Util::blessed($asset);
    push @$assets, $asset;
  }

  return $self->tap(sub { $_->{input}{$topic} = $assets }) if $self->{lazy};
  return $self->_process($topic => $assets);
}

sub processed { $_[0]->{by_topic}{$_[1]} }

sub register {
  my ($self, $app, $config) = @_;
  my $helper = $config->{helper} || 'asset';

  if ($app->renderer->helpers->{$helper}) {
    return $app->log->debug("AssetPack: Helper $helper() is already registered.");
  }

  $self->{input} = {};
  $self->{lazy} ||= $ENV{MOJO_ASSETPACK_LAZY} // $config->{lazy} || 0;
  $app->defaults('assetpack.helper' => $helper);
  $self->ua->server->app($app);
  Scalar::Util::weaken($self->ua->server->{app});

  if (my $proxy = $config->{proxy} // {}) {
    local $ENV{NO_PROXY} = $proxy->{no_proxy} || join ',', grep {$_} $ENV{NO_PROXY},
      $ENV{no_proxy}, '127.0.0.1', '::1', 'localhost';
    diag 'Detecting proxy settings. (NO_PROXY=%s)', $ENV{NO_PROXY} if DEBUG;
    $self->ua->proxy->detect;
  }

  if ($config->{pipes}) {
    $self->_pipes($config->{pipes});
    $app->helper($helper => sub { @_ == 1 ? $self : $self->_render_tags(@_) });
  }
  else {
    $app->log->warn(
      'https://metacpan.org/release/Mojolicious-Plugin-AssetPack-Backcompat is required');
    Test::More::diag("Loading DEPRECATED Mojolicious::Plugin::AssetPack::Backcompat.")
      if $ENV{HARNESS_ACTIVE} and UNIVERSAL::can(qw(Test::More diag));
    require Mojolicious::Plugin::AssetPack::Backcompat;
    @Mojolicious::Plugin::AssetPack::ISA = ('Mojolicious::Plugin::AssetPack::Backcompat');
    return $self->SUPER::register($app, $config);
  }
}

sub _app { shift->ua->server->app }

sub _correct_mode {
  my ($self, $args) = @_;

  while ($args =~ /\[(\w+)([!=]+)([^\]]+)/g) {
    my $v = $1 eq 'minify' ? $self->minify : $self->_app->$1;
    diag "Checking $1: $v $2 $3" if DEBUG == 2;
    return 0 if $2 eq '!=' and $v eq $3;
    return 0 if $2 ne '!=' and $v ne $3;    # default to testing equality
  }

  return 1;
}

sub _pipes {
  my ($self, $names) = @_;

  $self->{pipes} = [
    map {
      my $class = load_module /::/ ? $_ : "Mojolicious::Plugin::AssetPack::Pipe::$_";
      diag 'Loading pipe "%s".', $class if DEBUG;
      die qq(Unable to load "$_": $@) unless $class;
      my $pipe = $class->new(assetpack => $self);
      Scalar::Util::weaken($pipe->{assetpack});
      $pipe;
    } @$names
  ];
}

sub _process {
  my ($self, $topic, $input) = @_;
  my $assets = Mojo::Collection->new(@$input);    # Do not mess up input

  local $Mojolicious::Plugin::AssetPack::Util::TOPIC = $topic;    # Used by diag()

  for my $asset (@$assets) {
    if (my $prev = $self->{by_topic}{$topic}) {
      delete $asset->{$_} for qw(checksum format);
      $asset->content($self->store->asset($asset->url));
    }
    $asset->checksum;
  }

  for my $method (qw(before_process process after_process)) {
    for my $pipe (@{$self->{pipes}}) {
      next unless $pipe->can($method);
      local $pipe->{topic} = $topic;
      diag '%s->%s("%s")', ref $pipe, $method, $topic if DEBUG;
      $pipe->$method($assets);
      push @{$self->{asset_paths}}, $_->path->to_string for grep { $_->path } @$assets;
    }
  }

  my @checksum = map { $_->checksum } @$assets;
  $self->_app->log->debug(qq(Processed asset "$topic". [@checksum]));
  $self->{by_checksum}{$_->checksum} = $_ for @$assets;
  $self->{by_topic}{$topic} = $assets;
  $self;
}

sub _process_from_def {
  my $self  = shift;
  my $file  = shift || 'assetpack.def';
  my $asset = $self->store->file($file);
  my $topic = '';
  my %process;

  die qq(Unable to load "$file".) unless $asset;
  diag qq(Loading asset definitions from "$file".) if DEBUG;

  for (split /\r?\n/, $asset->slurp) {
    s/\s*\#.*//;
    if (/^\<(\S*)\s+(\S+)\s*(.*)/) {
      my ($class, $url, $args) = ($1, $2, $3);
      next unless $self->_correct_mode($args);
      my $asset = $self->store->asset($url);
      die qq(Could not find input asset "$url".) unless Scalar::Util::blessed($asset);
      bless $asset, 'Mojolicious::Plugin::AssetPack::Asset::Null' if $class eq '<';
      push @{$process{$topic}}, $asset;
    }
    elsif (/^\!\s*(.+)/) { $topic = trim $1; }
  }

  $self->process($_ => @{$process{$_}}) for keys %process;
  $self;
}

sub _render_tags {
  my ($self, $c, $topic, @attrs) = @_;
  my $route = $self->route;

  $self->_process($topic => $self->{input}{$topic}) if $self->{lazy};

  my $assets = $self->{by_topic}{$topic} ||= $self->_static_asset($topic);
  my %args = (base_url => $route->pattern->defaults->{base_url} || '', topic => $topic);
  $args{base_url} =~ s!/+$!!;

  return $assets->grep(sub { !$_->isa('Mojolicious::Plugin::AssetPack::Asset::Null') })
    ->map($self->tag_for, $c, \%args, @attrs)->join("\n");
}

sub _reset {
  my ($self, $args) = @_;

  diag "Reset $self." if DEBUG;

  if ($args->{unlink}) {
    for (@{$self->{asset_paths} || []}) {
      next unless /\bcache\b/;
      next unless -e;
      local $! = 0;
      unlink;
      diag 'unlink %s = %s', $_, $! || '1' if DEBUG;
    }
  }

  $self->store->_reset($args);
  delete $self->{$_} for qw(by_checksum by_topic);
}

sub _serve {
  my $c        = shift;
  my $checksum = $c->stash('checksum');
  my $helper   = $c->stash('assetpack.helper');
  my $self     = $c->$helper;

  if (my $f = $self->{by_checksum}{$checksum}) {
    $self->store->serve_asset($c, $f);
    return $c->rendered;
  }

  my $topic = $c->stash('name');
  if ($self->{by_topic}{$topic}) {
    return $c->render(text => "// Invalid checksum for topic '$topic'\n", status => 404);
  }

  $c->render(text => "// No such asset '$topic'\n", status => 404);
}

sub _static_asset {
  my ($self, $topic) = @_;
  my $asset = $self->store->asset($topic)
    or die qq(No assets registered by topic "$topic".);
  my $assets = Mojo::Collection->new($asset);
  $self->{by_checksum}{$_->checksum} = $_ for @$assets;
  return $assets;
}

sub DESTROY {
  my $self = shift;
  $self->_reset({unlink => 1}) if $ENV{MOJO_ASSETPACK_CLEANUP} and $self->{store};
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::AssetPack - Compress and convert css, less, sass, javascript and coffeescript files

=head1 VERSION

1.37

=head1 SYNOPSIS

=head2 Application

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

=head2 Template

  <html>
    <head>
      %= asset "app.css"
    </head>
    <body><%= content %></body>
  </html>

=head1 FOR EXISTING USERS

Are you already using AssetPack? You can still do so without any change. This
new version was written to make it easier to maintain and also easier to
extend. The new code will be "activated" by loadind this plugin with a list of
pipes:

  $app->plugin(AssetPack => {pipes => [...]});

The old API require L<Mojolicious::Plugin::AssetPack::Backcompat> to be installed.

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack> is L<Mojolicious plugin|Mojolicious::Plugin>
for processing static assets. The idea is that JavaScript and CSS files should
be served as one minified file to save bandwidth and roundtrip time to the
server.

There are many external tools for doing this, but integrating them with
L<Mojolicious> can be a struggle: You want to serve the source files directly
while developing, but a minified version in production. This assetpack plugin
will handle all of that automatically for you.

The actual processing is delegated to "pipe objects". Please see
L<Mojolicious::Plugin::AssetPack::Guides::Tutorial/Pipes> for a complete list.

=head1 GUIDES

=over 2

=item * L<Mojolicious::Plugin::AssetPack::Guides::Tutorial>

The tutorial will give an introduction to how AssetPack can be used.

=item * L<Mojolicious::Plugin::AssetPack::Guides::Cookbook>

The cookbook has various receipes on how to cook with AssetPack.

=back

=head1 ENVIRONMENT

It is possible to set environment variables to change the behavior of AssetPack:

=over 2

=item * MOJO_ASSETPACK_DEBUG

Set this environment variable to get more debug to STDERR. Currently you can
set it to a value between 0 and 3, where 3 provides the most debug.

=item * MOJO_ASSETPACK_LAZY

Set this environment variable if you want to delay processing the assets until
they are requested. This can be very useful while developing when the assets
are changed frequently.

=back

=head1 OPTIONAL MODULES

There are some optional modules you might want to install:

=over 2

=item * L<CSS::Minifier::XS>

Used by L<Mojolicious::Plugin::AssetPack::Pipe::Css>.

=item * L<CSS::Sass>

Used by L<Mojolicious::Plugin::AssetPack::Pipe::Sass>.

=item * L<IO::Socket::SSL>

Required if you want to download assets served over SSL.

=item * L<JavaScript::Minifier::XS>

Used by L<Mojolicious::Plugin::AssetPack::Pipe::JavaScript>.

=back

=head1 HELPERS

=head2 asset

  $self = $app->asset;
  $self = $c->asset;
  $bytestream = $c->asset($topic, @args);
  $bytestream = $c->asset("app.css", media => "print");

C<asset()> is the main entry point to this plugin. It can either be used to
access the L<Mojolicious::Plugin::AssetPack> instance or as a tag helper.

The helper name "asset" can be customized by specifying "helper" when
L<registering|/register> the plugin.

See L<Mojolicious::Plugin::AssetPack::Guides::Tutorial> for more details.

=head1 ATTRIBUTES

=head2 minify

  $bool = $self->minify;
  $self = $self->minify($bool);

Set this to true to combine and minify the assets. Defaults to false if
L<Mojolicious/mode> is "development" and true otherwise.

See L<Mojolicious::Plugin::AssetPack::Guides::Tutorial/Application mode>
for more details.

=head2 route

  $route = $self->route;
  $self = $self->route($route);

A L<Mojolicious::Routes::Route> object used to serve assets. The default route
responds to HEAD and GET requests and calls
L<serve_asset()|Mojolicious::Plugin::AssetPack::Store/serve_asset> on L</store>
to serve the asset.

The default route will be built and added to the L<application|Mojolicious>
when L</process> is called the first time.

See L<Mojolicious::Plugin::AssetPack::Guides::Cookbook/ASSETS FROM CUSTOM DOMAIN>
for an example on how to customize this route.

=head2 store

  $obj = $self->store;
  $self = $self->store(Mojolicious::Plugin::AssetPack::Store->new);

Holds a L<Mojolicious::Plugin::AssetPack::Store> object used to locate, store
and serve assets.

=head2 tag_for

  $self = $self->tag_for(sub { my ($asset, $c, \%args, @attrs) = @_; });
  $code = $self->tag_for;

Holds a sub reference that returns a L<Mojo::Bytestream> object containing the
markup required to render an asset.

C<$asset> is a L<Mojolicious::Plugin::AssetPack::Asset> object, C<$c> is an
L<Mojolicious::Controller> object and C<@attrs> can contain a list of
HTML attributes. C<%args> currently contains:

=over 4

=item * base_url

See L<Mojolicious::Plugin::AssetPack::Guides::Cookbook/ASSETS FROM CUSTOM DOMAIN>.

=item * topic

Name of the current topic.

=back

=head2 ua

  $ua = $self->ua;

Holds a L<Mojo::UserAgent> which can be used to fetch assets either from local
application or from remote web servers.

=head1 METHODS

=head2 pipe

  $obj = $self->pipe($name);
  $obj = $self->pipe("Css");

Will return a registered pipe by C<$name> or C<undef> if none could be found.

=head2 process

  $self = $self->process($topic => @assets);
  $self = $self->process($definition_file);

Used to process assets. A C<$definition_file> can be used to define C<$topic>
and C<@assets> in a seperate file. See
L<Mojolicious::Plugin::AssetPack::Guides::Tutorial/Process assets> for more
details.

C<$definition_file> defaults to "assetpack.def".

=head2 processed

  $collection = $self->processed($topic);

Can be used to retrieve a L<Mojo::Collection> object, with zero or more
L<Mojolicious::Plugin::AssetPack::Asset> objects. Returns undef if C<$topic> is
not defined with L</process>.

=head2 register

  $self->register($app, \%config);

Used to register the plugin in the application. C<%config> can contain:

=over 2

=item * helper

Name of the helper to add to the application. Default is "asset".

=item * pipes

This argument is mandatory and need to contain a complete list of pipes that is
needed. Example:

  $app->plugin(AssetPack => {pipes => [qw(Sass Css Combine)]);

See L<Mojolicious::Plugin::AssetPack::Guides::Tutorial/Pipes> for a complete
list of available pipes.

=item * proxy

A hash of proxy settings. Set this to C<0> to disable proxy detection.
Currently only "no_proxy" is supported, which will set which requests that
should bypass the proxy (if any proxy is detected). Default is to bypass all
requests to localhost.

See L<Mojo::UserAgent::Proxy/detect> for more infomation.

=back

=head1 SEE ALSO

L</GUIDES>,
L<Mojolicious::Plugin::AssetPack::Asset>,
L<Mojolicious::Plugin::AssetPack::Pipe> and
L<Mojolicious::Plugin::AssetPack::Store>.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

Alexander Rymasheusky

Mark Grimes - C<mgrimes@cpan.org>

Per Edin - C<info@peredin.com>

Viktor Turskyi

=cut
