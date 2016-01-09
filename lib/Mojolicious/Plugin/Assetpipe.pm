package Mojolicious::Plugin::Assetpipe;
use Mojo::Base 'Mojolicious::Plugin';
use Mojolicious::Plugin::Assetpipe::Asset;
use Mojolicious::Plugin::Assetpipe::Util qw(diag has_ro load_module DEBUG);

our $VERSION = '0.01';

has minify => sub { shift->_app->mode ne 'development' };

has route => sub {
  my $self = shift;
  Scalar::Util::weaken($self);
  $self->_app->routes->route('/asset/:checksum/:name')->via(qw( HEAD GET ))
    ->name('assetpipe')->to(cb => sub { $self->_serve(@_) });
};

has static => sub {
  my $self = shift;
  return Mojolicious::Static->new->classes([@{$self->_app->static->classes}])
    ->paths([$self->_app->home->rel_dir('assets')]);
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

  for my $pipe (@{$self->{pipes}}) {
    $pipe->topic($topic);
    for my $method (qw( _process _combine )) {
      next unless $pipe->can($method);
      diag '%s->%s($assets)', ref $pipe, $method if DEBUG;
      $pipe->$method($assets);
    }
  }

  $self->{by_topic}{$topic} = $assets;
  $self->{by_checksum}{$_->checksum} = $_ for @$assets;
  $self;
}

sub register {
  my ($self, $app, $config) = @_;
  my $helper = $config->{helper} || 'asset';

  $self->ua->server->app($app);
  Scalar::Util::weaken($self->ua->server->{app});

  if (my $proxy = $config->{proxy} // {}) {
    local $ENV{NO_PROXY} = $proxy->{no_proxy} || join ':', grep {$_} $ENV{NO_PROXY},
      $ENV{no_proxy}, '127.0.0.1', 'localhost';
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

sub _serve {
  my ($self, $c) = @_;
  my $asset = $self->{by_checksum}{$c->stash('checksum')} or return $c->reply->not_found;
  $self->static->serve_asset($c, $asset);
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

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::Assetpipe - Description

=head1 VERSION

0.01

=head1 DESCRIPTION

L<Mojolicious::Plugin::Assetpipe> is a ...

=head1 SYNOPSIS

  use Mojolicious::Plugin::Assetpipe;
  my $obj = Mojolicious::Plugin::Assetpipe->new;

=head1 ATTRIBUTES

=head1 METHODS

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut
