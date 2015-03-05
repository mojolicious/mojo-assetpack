package Mojolicious::Plugin::AssetPack::Preprocessor::CoffeeScript;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::AssetPack::Preprocessor::CoffeeScript - Preprocessor for CoffeeScript

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Preprocessor::CoffeeScript> is a preprocessor for
C<.coffee> files.

CoffeeScript is a little language that compiles into JavaScript. See
L<http://coffeescript.org> for more information.

Installation on Ubuntu or Debian:

  $ sudo apt-get install npm
  $ sudo npm install -g coffee-script

=cut

use Mojo::Base 'Mojolicious::Plugin::AssetPack::Preprocessor::JavaScript';
use File::Which              ();
use JavaScript::Minifier::XS ();

=head1 ATTRIBUTES

=head2 executable

  $path = $self->executable;

Holds the path to the "coffee" executable. Default to just "coffee".

=cut

has executable => sub { File::Which::which('coffee') || 'coffee' };

=head1 METHODS

=head2 can_process

Returns true if L</executable> points to an actual file.

=cut

sub can_process { -f $_[0]->executable ? 1 : 0 }

=head2 process

This method use "coffee" to process C<$text>.

See L<Mojolicious::Plugin::AssetPack::Preprocessor/process>.

=cut

sub process {
  my ($self, $assetpack, $text, $path) = @_;
  my @cmd = ($self->executable, '--compile', '--stdio');

  $self->_run(\@cmd, $text, $text);

  return $self->minify($text) if $assetpack->minify;
  return $self;
}

sub _url {'http://coffeescript.org/#installation'}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
