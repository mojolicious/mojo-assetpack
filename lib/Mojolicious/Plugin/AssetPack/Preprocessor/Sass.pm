package Mojolicious::Plugin::AssetPack::Preprocessor::Sass;

=head1 NAME

Mojolicious::Plugin::AssetPack::Preprocessor::Sass - Preprocessor for sass

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Preprocessor::Sass> is a preprocessor for
C<.sass> files.

Sass makes CSS fun again. Sass is an extension of CSS3, adding nested rules,
variables, mixins, selector inheritance, and more. See L<http://sass-lang.com>
for more information. Supports both F<*.scss> and F<*.sass> syntax variants.

You need either the "sass" executable or the cpan module L<CSS::Sass> to make
this module work:

  $ sudo apt-get install rubygems
  $ sudo gem install sass

  ...

  $ sudo cpanm CSS::Sass

=cut

use Mojo::Base 'Mojolicious::Plugin::AssetPack::Preprocessor::Scss';
use File::Basename 'dirname';
use constant LIBSASS_BINDINGS => $ENV{ENABLE_LIBSASS_BINDINGS} && eval 'require CSS::Sass;1';

=head2 process

This method use "sass" to process C<$text>.

See L<Mojolicious::Plugin::AssetPack::Preprocessor/process>.

=cut

sub process {
  my ($self, $assetpack, $text, $path) = @_;

  if (LIBSASS_BINDINGS) {
    $$text = CSS::Sass::sass2scss($$text);
    return $self->SUPER::process($assetpack, $text, $path);
  }
  else {
    my @cmd = ($self->executable, '--stdin', '-I' => dirname $path);
    push @cmd, qw( -t compressed) if $assetpack->minify;
    $self->_run(\@cmd, $text, $text);
  }

  return $self;
}

sub _extension {'sass'}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
