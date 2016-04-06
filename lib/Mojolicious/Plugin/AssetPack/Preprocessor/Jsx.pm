package Mojolicious::Plugin::AssetPack::Preprocessor::Jsx;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::AssetPack::Preprocessor::Jsx - Preprocessor for JavaScript XML syntax (react.js)

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Preprocessor::Jsx> is a preprocessor for
C<.jsx> files.

JSX is a JavaScript XML syntax transform recommended for use with
L<React|http://facebook.github.io/react>. See
L<http://facebook.github.io/react/docs/jsx-in-depth.html> for more information.

Installation on Ubuntu and Debian:

  $ sudo apt-get install npm
  $ sudo npm install -g react-tools

=cut

use Mojo::Base 'Mojolicious::Plugin::AssetPack::Preprocessor::JavaScript';
use File::Which ();

=head1 ATTRIBUTES

=head2 executable

  $path = $self->executable;

Holds the path to the "jsx" executable. Default to just "jsx".

=cut

has executable => sub { File::Which::which('jsx') || 'jsx' };

=head1 METHODS

=head2 can_process

Returns true if L</executable> points to an actual file.

=cut

sub can_process { -f $_[0]->executable ? 1 : 0 }

=head2 process

This method use "jsx" to process C<$text>.

See L<Mojolicious::Plugin::AssetPack::Preprocessor/process>.

=cut

sub process {
  my ($self, $assetpack, $text, $path) = @_;
  my $out;

  unless (eval { $self->_run([$self->executable], $text, $text) }) {
    $@ =~ s!\s*at throwError.*!!s unless $ENV{MOJO_ASSETPACK_DEBUG};
    $@ =~ s!\x1B\[\d{1,2}m!!g;    # remove color codes
    die $@;
  }

  return $self->minify($text) if $assetpack->minify;
  return $self;
}

sub _url {'http://facebook.github.io/react'}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
