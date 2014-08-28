package Mojolicious::Plugin::AssetPack::Preprocessor::Sass;

=head1 NAME

Mojolicious::Plugin::AssetPack::Preprocessor::Sass - Preprocessor for .sass files

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Preprocessor::Sass> is a preprocessor for
C<.sass> files.

=cut

use Mojo::Base 'Mojolicious::Plugin::AssetPack::Preprocessor';
use File::Basename 'dirname';
use File::Which ();

=head1 ATTRIBUTES

=head2 executable

  $path = $self->executable;

Holds the path to the "sass" executable, if it could be found.

=cut

has executable => File::Which::which('sass');

=head1 METHODS

=head2 process

This method use "sass" to process C<$text>.

See L<Mojolicious::Plugin::AssetPack::Preprocessor/process>.

=cut

sub process {
  my ($self, $assetpack, $text, $path) = @_;
  my @cmd = ( $self->executable, '--stdin' );

  push @cmd, '-I' => dirname $path;
  push @cmd, qw( -t compressed) if $assetpack->minify;

  Mojolicious::Plugin::AssetPack::Preprocessors->_run(\@cmd, $text, $text);

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
