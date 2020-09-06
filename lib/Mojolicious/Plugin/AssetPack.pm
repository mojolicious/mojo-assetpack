package Mojolicious::Plugin::AssetPack;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::Util qw(deprecated trim xml_escape);
use Mojolicious::Plugin::AssetPack::Asset::Null;
use Mojolicious::Plugin::AssetPack::Store;
use Mojolicious::Plugin::AssetPack::Util qw(diag has_ro load_module DEBUG);

our $VERSION = '2.09';

has minify => sub { shift->_app->mode eq 'development' ? 0 : 1 };

has route => sub {
  shift->_app->routes->route('/asset/:checksum/*name')->via(qw(HEAD GET))->name('assetpack')->to(cb => \&_serve);
};

has store => sub {
  my $self = shift;
  Mojolicious::Plugin::AssetPack::Store->new(
    classes => [@{$self->_app->static->classes}],
    paths   => [$self->_app->home->rel_file('assets')],
    ua      => $self->ua,
  );
};

has_ro ua => sub { Mojo::UserAgent->new->max_redirects(3) };

sub pipe {
  my ($self, $needle) = @_;
  return +(grep { $_ =~ /::$needle\b/ } @{$self->{pipes}})[0];
}

sub process {
  my ($self, $topic, @input) = @_;

  $self->route                            unless $self->{route_added}++;
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

sub processed {
  my ($self, $topic) = @_;
  $self->_process($topic => $self->{input}{$topic}) unless $self->{by_topic}{$topic};    # Ensure asset is processed
  return $self->{by_topic}{$topic};
}

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
    local $ENV{NO_PROXY} = $proxy->{no_proxy} || join ',', grep {$_} $ENV{NO_PROXY}, $ENV{no_proxy}, '127.0.0.1',
      '::1', 'localhost';
    diag 'Detecting proxy settings. (NO_PROXY=%s)', $ENV{NO_PROXY} if DEBUG;
    $self->ua->proxy->detect;
  }

  $self->_pipes($config->{pipes} || []);
  $app->helper($helper => sub { @_ == 1 ? $self : $self->_render_tags(@_) });
}

sub tag_for {
  my $self = shift;
  deprecated 'tag_for() is DEPRECATED in favor of Mojolicious::Plugin::AssetPack::Asset::tag_for()';
  return $self->{tag_for} unless @_;
  $self->{tag_for} = shift;
  return $self;
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
    }
  }

  if (my $tag_for = $self->{tag_for}) {
    $_->{tag_for} or $_->{tag_for} = $tag_for for @$assets;
  }

  my @checksum = map { $_->checksum } @$assets;
  $self->_app->log->debug(qq(Processed asset "$topic". [@checksum])) if DEBUG;
  $self->{by_checksum}{$_->checksum} = $_ for @$assets;
  $self->{by_topic}{$topic} = $assets;
  $self->store->persist;
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
  my %args   = (base_url => $route->pattern->defaults->{base_url} || '', topic => $topic);
  $args{base_url} =~ s!/+$!!;

  return Mojo::ByteStream->new(
    join "\n",
    map    { $_->tag_for->($_, $c, \%args, @attrs) }
      grep { !$_->isa('Mojolicious::Plugin::AssetPack::Asset::Null') } @$assets
  );
}

sub _serve {
  my $c      = shift;
  my $helper = $c->stash('assetpack.helper');
  my $self   = $c->$helper;

  my $checksum = $c->stash('checksum');
  if (my $asset = $self->{by_checksum}{$checksum}) {
    $self->store->serve_asset($c, $asset);
    return $c->rendered;
  }

  my $topic = $c->stash('name');
  if (my $assets = $self->{by_topic}{$topic}) {
    return $self->store->serve_fallback_for_assets($c, $topic, $assets);
  }

  $c->render(text => sprintf("// No such asset '%s'\n", xml_escape $topic), status => 404);
}

sub _static_asset {
  my ($self, $topic) = @_;
  my $asset  = $self->store->asset($topic) or die qq(No assets registered by topic "$topic".);
  my $assets = Mojo::Collection->new($asset);
  $self->{by_checksum}{$_->checksum} = $_ for @$assets;
  return $assets;
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::AssetPack - Compress and convert css, less, sass, javascript and coffeescript files

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack> has a very limited feature set, especially
when it comes to processing JavaScript. It is recommended that you switch to
L<Mojolicious::Plugin::Webpack> if you want to write modern JavaScript code.

=head2 Existing user?

It is I<very> simple to migrate from L<Mojolicious::Plugin::AssetPack> to
L<Mojolicious::Plugin::Webpack>. Just check out the one line change in
L<Mojolicious::Plugin::Webpack/MIGRATING-FROM-ASSETPACK>.

=head2 Don't want to switch?

Your existing code will probably continue to work for a long time, but it will
get more and more difficult to write I<new> working JavaScript with
L<Mojolicious::Plugin::AssetPack> as time goes by.

=head2 New user?

Look no further. Just jump over to L<Mojolicious::Plugin::Webpack>.

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

=head1 ATTRIBUTES

=head2 minify

  $bool = $self->minify;
  $self = $self->minify($bool);

Set this to true to combine and minify the assets. Defaults to false if
L<Mojolicious/mode> is "development" and true otherwise.

=head2 route

  $route = $self->route;
  $self = $self->route($route);

A L<Mojolicious::Routes::Route> object used to serve assets. The default route
responds to HEAD and GET requests and calls
L<serve_asset()|Mojolicious::Plugin::AssetPack::Store/serve_asset> on L</store>
to serve the asset.

The default route will be built and added to the L<application|Mojolicious>
when L</process> is called the first time.

=head2 store

  $obj = $self->store;
  $self = $self->store(Mojolicious::Plugin::AssetPack::Store->new);

Holds a L<Mojolicious::Plugin::AssetPack::Store> object used to locate, store
and serve assets.

=head2 tag_for

Deprecated. Use L<Mojolicious::Plugin::AssetPack::Asset/renderer> instead.

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
and C<@assets> in a separate file.

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

=item * proxy

A hash of proxy settings. Set this to C<0> to disable proxy detection.
Currently only "no_proxy" is supported, which will set which requests that
should bypass the proxy (if any proxy is detected). Default is to bypass all
requests to localhost.

See L<Mojo::UserAgent::Proxy/detect> for more information.

=back

=head1 SEE ALSO

L<Mojolicious::Plugin::Webpack>.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2020, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

Alexander Rymasheusky

Mark Grimes - C<mgrimes@cpan.org>

Per Edin - C<info@peredin.com>

Viktor Turskyi

=cut
