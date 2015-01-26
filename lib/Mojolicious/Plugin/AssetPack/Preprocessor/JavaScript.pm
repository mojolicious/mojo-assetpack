package Mojolicious::Plugin::AssetPack::Preprocessor::JavaScript;

=head1 NAME

Mojolicious::Plugin::AssetPack::Preprocessor::JavaScript - Preprocessor for JavaScript

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Preprocessor::JavaScript> is a preprocessor for
C<.js> files.

JavaScript is minified using L<JavaScript::Minifier::XS>. This module is
optional and must be installed manually.

NOTE! L<JavaScript::Minifier::XS> might be replaced with something better.

=cut

use Mojo::Base 'Mojolicious::Plugin::AssetPack::Preprocessor';
use JavaScript::Minifier::XS;

=head1 METHODS

=head2 minify

  $self = $self->minify($text);

Used to minify C<$text>, which is a scalar reference to a chunk of JavaScript
code.

=cut

sub minify {
  my ($self, $text) = @_;

  if (length $$text) {
    $$text = JavaScript::Minifier::XS::minify($$text) // die "JavaScript::Minifier::XS failed with undefined error.";
  }

  $self;
}

=head2 process

This method use L<JavaScript::Minifier::XS> to process C<$text>.

See L<Mojolicious::Plugin::AssetPack::Preprocessor/process>.

=cut

sub process {
  my ($self, $assetpack, $text, $path) = @_;

  return $self->minify($text) if $assetpack->minify;
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
