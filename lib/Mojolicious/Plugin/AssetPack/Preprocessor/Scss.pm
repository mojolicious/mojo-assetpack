package Mojolicious::Plugin::AssetPack::Preprocessor::Scss;

=head1 NAME

Mojolicious::Plugin::AssetPack::Preprocessor::Scss - Preprocessor for .scss files

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Preprocessor::Scss> is a preprocessor for
C<.scss> files. This module inherite all the functionality from
L<Mojolicious::Plugin::AssetPack::Preprocessor::Sass>.

=cut

use Mojo::Base 'Mojolicious::Plugin::AssetPack::Preprocessor::Sass';
use File::Basename 'dirname';
use File::Which ();

=head1 METHODS

=head2 process

This method use "sass" to process C<$text>.

See L<Mojolicious::Plugin::AssetPack::Preprocessor/process>.

=cut

sub process {
  my ($self, $assetpack, $text, $path) = @_;
  my @cmd = ( $self->executable, '--stdin', '--scss' );

  push @cmd, '-I' => dirname $path;
  push @cmd, qw( -t compressed) if $assetpack->minify;
  push @cmd, qw( --compass ) if !$ENV{MOJO_ASSETPACK_NO_COMPASS} and $$text =~ m!\@import\W+compass\/!;

  Mojolicious::Plugin::AssetPack::Preprocessors->_run(\@cmd, $text, $text);

  return $self;
}

sub _extension { 'scss' }

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
