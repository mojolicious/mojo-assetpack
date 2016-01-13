package Mojolicious::Plugin::Assetpipe;
use Mojo::Base 'Mojolicious::Plugin';
use Mojolicious::Plugin::Assetpipe::Asset;
use Mojolicious::Plugin::Assetpipe::Store;
use Mojolicious::Plugin::Assetpipe::Util qw(diag has_ro load_module DEBUG);

our $VERSION = '0.01';

has minify => sub { shift->_app->mode ne 'development' };

has route => sub {
  my $self = shift;
  Scalar::Util::weaken($self);
  $self->_app->routes->route('/asset/:checksum/:name')->via(qw( HEAD GET ))
    ->name('assetpipe')->to(cb => sub { $self->_serve(@_) });
};

has store => sub {
  my $self = shift;
  Mojolicious::Plugin::Assetpipe::Store->new(
    classes => [@{$self->_app->static->classes}],
    paths   => [$self->_app->home->rel_dir('assets')]
  );
};

has_ro ua => sub { Mojo::UserAgent->new->max_redirects(3) };

sub process {
  my ($self, $topic) = (shift, shift);

  # Used by diag()
  local $Mojolicious::Plugin::Assetpipe::Util::TOPIC = $topic;

  # TODO: The idea with blessed($_) is that maybe the user can pass inn
  # Mojolicious::Plugin::Assetpipe::Sprites object, with images to generate
  # CSS from?
  my $assets = Mojo::Collection->new(
    map {
      Scalar::Util::blessed($_)
        ? $_
        : Mojolicious::Plugin::Assetpipe::Asset->new(assetpipe => $self, url => $_)
    } @_
  );

  # Prepare asset attributes
  $assets->map($_) for qw(checksum mtime);

  for my $pipe (@{$self->{pipes}}) {
    $pipe->topic($topic);
    for my $method (qw( _process _combine )) {
      next unless $pipe->can($method);
      diag '%s->%s($assets)', ref $pipe, $method if DEBUG;
      $pipe->$method($assets);
      $self->{by_checksum}{$_->checksum} = $_ for @$assets;
    }
  }

  $self->{by_checksum}{$_->checksum} = $_ for @$assets;
  $self->{by_topic}{$topic} = $assets;
  $self;
}

sub register {
  my ($self, $app, $config) = @_;
  my $helper = $config->{helper} || 'asset';

  $self->ua->server->app($app);
  Scalar::Util::weaken($self->ua->server->{app});

  if (my $proxy = $config->{proxy} // {}) {
    local $ENV{NO_PROXY} = $proxy->{no_proxy} || join ',', grep {$_} $ENV{NO_PROXY},
      $ENV{no_proxy}, '127.0.0.1', '::1', 'localhost';
    diag 'Detecting proxy settings. (NO_PROXY=%s)', $ENV{NO_PROXY} if DEBUG;
    $self->ua->proxy->detect;
  }

  $self->_pipes($config->{pipes});
  $app->helper($helper => sub { @_ == 1 ? $self : $self->_tag_helpers(@_) });
}

sub _app { shift->ua->server->app }

sub _pipes {
  my $self = shift;
  my $names = shift || [qw(Css JavaScript Combine)];

  $self->{pipes} = [
    map {
      my $class = load_module /::/ ? $_ : "Mojolicious::Plugin::Assetpipe::Pipe::$_";
      diag 'Loading pipe "%s".', $class if DEBUG;
      die qq(Unable to load "$_": $@) unless $class;
      $class->new(assetpipe => $self);
    } @$names
  ];
}

sub _reset {
  my ($self, $args) = @_;

  diag 'Reset assetpipe.' if DEBUG;

  if ($args->{unlink}) {
    for my $asset (sort values %{$self->{by_checksum} || {}}) {
      next unless +(my $file = $asset->_asset)->isa('Mojo::Asset::File');
      my $rel_path = File::Spec->catfile($self->store->_cache_path($asset));
      diag "unlink? %s =~ %s", $file->path, $rel_path if DEBUG == 10;
      next unless $file->path =~ /$rel_path$/;
      unlink $file->path;
      diag 'unlink %s: %s', $file->path, $! || 1;
    }
  }

  delete $self->{$_} for qw(by_checksum by_topic);
}

sub _serve {
  my ($self, $c) = @_;
  my $asset = $self->{by_checksum}{$c->stash('checksum')} or return $c->reply->not_found;
  $self->store->serve_asset($c, $asset);
  $c->rendered;
}

sub _tag_helpers {
  my ($self, $c, $topic, @attrs) = @_;
  my $route  = $self->route;
  my $assets = $self->{by_topic}{$topic}
    or die qq(No assets registered by topic "$topic".);

  return $assets->map(
    sub {
      my $tag_helper = $_->format eq 'js' ? 'javascript' : 'stylesheet';
      my $url = $route->render(
        {checksum => $_->checksum, format => $_->format, name => $_->name});
      $c->$tag_helper($url, @attrs);
    }
  )->join("\n");
}

sub DESTROY {
  shift->_reset({unlink => 1}) if $ENV{MOJO_ASSETPIPE_CLEANUP};
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::Assetpipe - EXPERIMENTAL alternative to AssetPack

=head1 VERSION

0.01

=head1 SYNOPSIS

=head2 Application

  use Mojolicious::Lite;

  # Load plugin
  plugin "assetpipe";

  # define asset
  app->asset->process(
    "app.css" => (              # virtual name of the asset
      "sass/bar.scss",          # relative to store()
      "/usr/share/vendor.css",  # absolute path
    )
  );

=head2 Template

  <html>
    <head>
      %= asset "app.css"
    </head>
    <body><%= content %></body>
  </html>

=head1 DESCRIPTION

L<Mojolicious::Plugin::Assetpipe> is L<Mojolicious plugin|Mojolicious::Plugin>
for processing static assets. The idea is that JavaScript and CSS files should
be served as one minified file to save bandwidth and roundtrip time to the
server.

There are many external tools for doing this, but integrating the with
L<Mojolicious> can be a struggle: You want to serve the source files directly
while developing, but a minified version in production. This assetpipe plugin
will handle all of that automatically for you.

L<Mojolicious::Plugin::Assetpipe> does not do any heavy lifting itself: All the
processing is left to the L<pipe objects|Mojolicious::Plugin::Assetpipe::Pipe>.

It is possible to specify L<custom pipes|/register>, but there are also some
pipes bundled with this distribution which is loaded automatically:

=over 4

=item * L<Mojolicious::Plugin::Assetpipe::Pipe::Combine>

Combine multiple assets to one.

=item * L<Mojolicious::Plugin::Assetpipe::Pipe::Css>

Minify CSS.

=item * L<Mojolicious::Plugin::Assetpipe::Pipe::JavaScript>

Minify JavaScript.

=back

Future releases will have more pipes bundled.

=head1 ATTRIBUTES

=head2 minify

  $bool = $self->minify;
  $self = $self->minify($bool);

Set this to true to combine and minify the assets. Will be true unless
L<Mojolicious/mode> is "development".

=head2 route

  $route = $self->route;
  $self = $self->route($route);

The route used to generate paths to assets and also dispatch to a callback
which can serve the assets.

=head2 store

  $obj = $self->store;
  $self = $self->store(Mojolicious::Plugin::Assetpipe::Store->new);

Holds a L<Mojolicious::Plugin::Assetpipe::Store> object used to locate and
store assets. Assets can be located on disk or in a L<DATA|Mojo::Util/data_section>
section.

=head2 ua

  $ua = $self->ua;

Holds a L<Mojo::UserAgent> which can be used to fetch assets either from local
application or from remote web servers.

=head1 METHODS

=head2 process

  $self = $self->process($topic => @assets);

Used to process assets.

=head2 register

  $self->register($app, \%config);

Used to register the plugin in the application. C<%config> can contain:

=over 2

=item * helper

Name of the helper to add to the application. Default is "asset".

=item * pipes

A list of pipe classes to load. The default is:

  [qw( Css JavaScript Combine )];

Note! The default will change when more pipe classes are added.

=item * proxy

A hash of proxy settings. Set this to C<undef> to disable proxy detection.
Currently only "no_proxy" is supported, which will set which requests that
should bypass the proxy (if any proxy is detected). Default is to bypass
all requests to localhost.

See L<Mojo::UserAgent::Proxy/detect> for more infomation.

=back

=head1 SEE ALSO

L<Mojolicious::Plugin::Assetpipe::Asset>,
L<Mojolicious::Plugin::Assetpipe::Pipe> and
L<Mojolicious::Plugin::Assetpipe::Store>.

L<Mojolicious::Plugin::Assetpipe> is a re-implementation of
L<Mojolicious::Plugin::AssetPack>.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut
