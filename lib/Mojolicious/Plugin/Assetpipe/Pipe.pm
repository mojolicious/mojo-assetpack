package Mojolicious::Plugin::Assetpipe::Pipe;
use Mojo::Base -base;
use Mojolicious::Plugin::Assetpipe::Asset;
use Mojolicious::Plugin::Assetpipe::Util 'has_ro';

has topic => '';
has_ro 'assetpipe';

sub new {
  my $self = shift->SUPER::new(@_);
  Scalar::Util::weaken($self->{assetpipe});
  $self;
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::Assetpipe::Pipe - Base class for a pipe

=head1 DESCRIPTION

This is the base class for all pipe classes.

=head1 ATTRIBUTES

=head2 assetpipe

  $obj = $self->assetpipe;

Holds a L<Mojolicious::Plugin::Assetpipe> object.

=head2 topic

  $str = $self->topic;
  $self = $self->topic("app.css");

Returns the name of the current asset topic.

=head1 METHODS

=head2 new

Object constructor. Makes sure L</assetpipe> is weaken.

=head1 SEE ALSO

L<Mojolicious::Plugin::Assetpipe>.

=cut
