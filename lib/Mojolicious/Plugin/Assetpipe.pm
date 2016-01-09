package Mojolicious::Plugin::Assetpipe;
use Mojo::Base 'Mojolicious::Plugin';

our $VERSION = '0.01';

has route => sub {
  my $self = shift;
  Scalar::Util::weaken($self);
  $self->_app->routes->route('/asset/:name/:checksum')->via(qw( HEAD GET ))
    ->name('assetpipe')->to(cb => sub { $self->_serve(@_) });
};

# read-only attribute
sub ua { $_[0]->{ua} ||= Mojo::UserAgent->new->max_redirects(3) }

sub process {
  my ($self, $topic) = (shift, shift);
  my $sources = Mojo::Collection->new(@_);
  my $assets  = Mojo::Collection->new;

  $self->{by_topic}{$topic} = $assets;
  $self;
}

sub register {
  my ($self, $app, $config) = @_;
  my $helper = $config->{helper} || 'asset';

  $self->ua->server->app($app);
  Scalar::Util::weaken($self->ua->server->{app});

  if (my $proxy = $config->{proxy} // {}) {
    local $ENV{NO_PROXY} = $proxy->{no_proxy} || join ':', grep {$_} $ENV{NO_PROXY},
      $ENV{no_proxy}, '127.0.0.1', '::1', 'localhost';
    $self->ua->proxy->detect;
  }

  $app->helper($helper => sub { @_ == 1 ? $self : $self->_tag_helpers(@_) });
}

sub _app { shift->ua->server->app }

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
