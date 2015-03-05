package Mojolicious::Plugin::AssetPack::Preprocessor::Css;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::AssetPack::Preprocessor::Css - Preprocessor for CSS

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Preprocessor::Css> is a preprocessor for
C<.css> files.

CSS is minified using L<CSS::Minifier::XS>. This module is optional and must
be installed manually.

NOTE! L<CSS::Minifier::XS> might be replaced with something better.

=cut

use Mojo::Base 'Mojolicious::Plugin::AssetPack::Preprocessor';
use CSS::Minifier::XS;

=head1 METHODS

=head2 process

This method use L<CSS::Minifier::XS> to process C<$text>.

See L<Mojolicious::Plugin::AssetPack::Preprocessor/process>.

=cut

sub process {
  my ($self, $assetpack, $text, $path) = @_;

  if ($assetpack->minify and length $$text) {
    $$text = CSS::Minifier::XS::minify($$text) // die "CSS::Minifier::XS::minify could not minify $path";
  }

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
