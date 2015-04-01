package Mojolicious::Plugin::AssetPack::Asset;

=head1 NAME

Mojolicious::Plugin::AssetPack::Asset - AssetPack asset storage

=head1 VERSION

0.01

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Asset> is storage class for assets.

This class is EXPERIMENTAL.

=cut

use Mojo::Base 'Mojo::Asset::Memory';
use Mojo::Util     ();
use Cwd            ();
use Carp           ();
use File::Basename ();

=head1 ATTRIBUTES

=head2 in_memory

Boolean true if this file only exists in memory, false if stored on disk.

=head2 url

Either location on disk, HTTP URL or a virtual location (in case of L</in_memory>).

=cut

has in_memory => 1;
has url       => '';

=head1 METHODS

=head2 add_chunk

  $self = $self->add_chunk($bytes);

Will store data internally, which later can be written to disk using L</save>.

=cut

sub add_chunk {
  my ($self, $chunk) = @_;
  $self->{content} //= '';
  $self->{content} .= $chunk;
  $self;
}

=head2 basename

Returns the basename of L</url>.

=cut

sub basename { File::Basename::basename(shift->url); }

=head2 slurp

  $bytes = $self->slurp;

Read in the contents of the asset. Returns the data from L</add_chunk>
if L</in_memory> is true.

=cut

sub slurp {
  my $self = shift;
  $self->in_memory ? $self->{content} // '' : Mojo::Util::slurp($self->url);
}

=head2 save

  $self = $self->->save;

L</save> is used to write all the L</add_chunk> data to disk.

This method does nothing if L</in_memory> is true.

=cut

sub save {
  my $self = shift;

  return $self if $self->in_memory;
  die "Nothing to save to @{[$self->url]}" unless defined $self->{content};
  Mojo::Util::spurt(delete $self->{content}, $self->url);
  return $self;
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
