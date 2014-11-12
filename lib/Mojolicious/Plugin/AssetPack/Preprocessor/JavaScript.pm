package Mojolicious::Plugin::AssetPack::Preprocessor::JavaScript;

=head1 NAME

Mojolicious::Plugin::AssetPack::Preprocessor::JavaScript - Preprocessor for JavaScript

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Preprocessor::JavaScript> is a preprocessor for
C<.js> files.

Javascript is minified using L<JavaScript::Minifier::XS>. This module is
optional and must be installed manually.

NOTE! L<JavaScript::Minifier::XS> might be replaced with something better.

=cut

use Mojo::Base 'Mojolicious::Plugin::AssetPack::Preprocessor';
use Mojo::Util 'slurp';
use File::Basename 'dirname';
use JavaScript::Minifier::XS;

require Mojolicious::Plugin::AssetPack::Preprocessors;    # Mojolicious::Plugin::AssetPack::Preprocessors::CWD

=head1 METHODS

=head2 process

This method use L<JavaScript::Minifier::XS> to process C<$text>.

See L<Mojolicious::Plugin::AssetPack::Preprocessor/process>.

=cut

sub process {
  my ($self, $assetpack, $text, $path) = @_;

  if (!$ENV{MOJO_ASSETPACK_NO_FOLLOW_REQUIRES}) {
    $self->_follow_requires($assetpack, $text, $path);
  }

  if ($assetpack->minify and $path !~ /\bmin\b/ and length $$text) {
    $$text = JavaScript::Minifier::XS::minify($$text);
    $$text = "alert('Failed to minify $path')\n" unless defined $$text;
  }

  return $self;
}

sub _follow_requires {
  my ($self, $assetpack, $text, $path) = @_;
  my $cwd = Mojolicious::Plugin::AssetPack::Preprocessors::CWD->new(dirname $path);
  my $ext = $path =~ /\.(\w+)$/ ? $1 : 'js';

  $$text =~ s!\brequire\s*\(\s*(["'])(.+)+\1\s*\)\s*!{
    my $text = slurp "$2.$ext";
    $self->process($assetpack, \$text, "$2.$ext");
    "(function() { var module = {exports:{}};\n$text\nreturn module.exports; })()";
  }!ge;
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
