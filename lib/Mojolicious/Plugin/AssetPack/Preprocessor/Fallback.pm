package Mojolicious::Plugin::AssetPack::Preprocessor::Fallback;

=head1 NAME

Mojolicious::Plugin::AssetPack::Preprocessor::Fallback - Render missing preprocessor text

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Preprocessor::Fallback> will render a CSS with
an error message.

=cut

use Mojo::Base 'Mojolicious::Plugin::AssetPack::Preprocessor';

=head1 METHODS

=head2 can_process

Will always return false.

=cut

sub can_process {0}

=head2 process

Will simply die.

=cut

sub process {
  my ($self, $assetpack, $text, $path) = @_;
  die "No preprocessor defined for $path";
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
