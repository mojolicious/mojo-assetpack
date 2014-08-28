package Mojolicious::Plugin::AssetPack::Preprocessor;

=head1 NAME

Mojolicious::Plugin::AssetPack::Preprocessor - Base class for preprocessors

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Preprocessor> is a base class for preprocessors.

=cut

use Mojo::Base -base;
use overload (
  q(&{}) => sub { shift->can('process') },
  fallback => 1,
);

=head1 ATTRIBUTES

=head1 METHODS

=head2 process

  $self = $self->process($assetpack, $text, $path);

This method is used to process a given C<$text>. C<$text> is a scalar ref,
holding the text from the asset at location C<$path>. C<$assetpack> is
an L<Mojolicious::Plugin::AssetPack> instance.

=cut

sub process {
  my ($self, $assetpack, $text, $path) = @_;
  die "No pre-processor defined for $path" unless $self->{processor};
  $self->{processor}->($assetpack, $text, $path);
  $self;
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
