package Mojolicious::Plugin::AssetPack::Preprocessor::Less;

=head1 NAME

Mojolicious::Plugin::AssetPack::Preprocessor::Less - Preprocessor for LESS

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Preprocessor::Less> is a preprocessor for
C<.less> files.

LESS extends CSS with dynamic behavior such as variables, mixins, operations
and functions. See L<http://lesscss.org> for more details.

Installation on Ubuntu and Debian:

  $ sudo apt-get install npm
  $ sudo npm install -g less

=cut

use Mojo::Base 'Mojolicious::Plugin::AssetPack::Preprocessor';
use File::Which ();

=head1 ATTRIBUTES

=head2 executable

  $path = $self->executable;

Holds the path to the "lessc" executable. Default to just "lessc".

=cut

has executable => sub { File::Which::which('lessc') || 'lessc' };

=head1 METHODS

=head2 can_process

Returns true if L</executable> points to an actual file.

=cut

sub can_process { -f $_[0]->executable ? 1 : 0 }

=head2 process

This method use "lessc" to process C<$text>.

See L<Mojolicious::Plugin::AssetPack::Preprocessor/process>.

=cut

sub process {
  my ($self, $assetpack, $text, $path) = @_;
  my @cmd = ($self->executable);
  my $err;

  push @cmd, '-';                          # read from stdin
  push @cmd, '-x' if $assetpack->minify;

  $self->_run(\@cmd, $text, $text, \$err);
  $self->_make_css_error($err, $text) if length $err;
}

sub _url {'http://lesscss.org/#usage'}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
