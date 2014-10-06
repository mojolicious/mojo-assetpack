package Mojolicious::Plugin::AssetPack::Preprocessor::Scss;

=head1 NAME

Mojolicious::Plugin::AssetPack::Preprocessor::Scss - Preprocessor for .scss files

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Preprocessor::Scss> is a preprocessor for
C<.scss> files. This module inherite all the functionality from
L<Mojolicious::Plugin::AssetPack::Preprocessor::Sass>.

=head1 COMPASS

Compass is an open-source CSS Authoring Framework built on top of L</sass>.
See L<http://compass-style.org/> for more information.

Installation on Ubuntu and Debian:

  $ sudo apt-get install rubygems
  $ sudo gem install compass

This module will try figure out if "compass" is required to process your
C<*.scss> files. This is done with this regexp on the top level sass file:

  m!\@import\W+compass\/!;

NOTE! Compass support is experimental.

You can disable compass detection by setting the environment variable
C<MOJO_ASSETPACK_NO_COMPASS> to a true value.

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
  my @cmd = ($self->executable, '--stdin', '--scss');
  my $err;

  push @cmd, '-I' => dirname $path;
  push @cmd, qw( -t compressed) if $assetpack->minify;
  push @cmd, qw( --compass ) if !$ENV{MOJO_ASSETPACK_NO_COMPASS} and $$text =~ m!\@import\W+compass\/!;

  $self->_run(\@cmd, $text, $text, \$err);
  $self->_make_css_error($err, $text) if length $err;
}

sub _extension {'scss'}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
