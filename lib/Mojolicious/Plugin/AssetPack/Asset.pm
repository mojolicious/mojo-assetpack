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
use constant DEBUG => $ENV{MOJO_ASSETPACK_DEBUG} || 0;

=head1 ATTRIBUTES

=head2 content

  $self = $self->content($data);
  $data = $self->content;

=head2 in_memory

Boolean true if this file only exists in memory, false if stored on disk.

=head2 path

Either location on disk or a virtual location.

=cut

has content   => '';
has in_memory => 1;
has path      => '';

=head1 METHODS

=head2 basename

Returns the basename of L</path>.

=cut

sub basename { File::Basename::basename(shift->path); }

=head2 slurp

  $bytes = $self->slurp;

Read in the contents of the asset. Returns the data from L</content>
if L</in_memory> is true.

=cut

sub slurp {
  my $self = shift;
  $self->in_memory ? $self->{content} // '' : Mojo::Util::slurp($self->path);
}

=head2 save

  $self = $self->->save;

L</save> is used to write L</content> to disk. This method does nothing if
L</in_memory> is true.

=cut

sub save {
  my $self = shift;

  if (not defined $self->{content}) {
    die "Cannot save empty asset to save to @{[$self->path]}";
  }
  elsif ($self->in_memory) {
    warn "[ASSETPACK] Skip save of @{[$self->path]}\n" if DEBUG;
  }
  else {
    warn "[ASSETPACK] Save @{[$self->path]}\n" if DEBUG;
    Mojo::Util::spurt(delete $self->{content}, $self->path);
  }

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
