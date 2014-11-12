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
    my $cwd = Mojolicious::Plugin::AssetPack::Preprocessors::CWD->new(dirname $path);
    $self->_follow_requires($text, $path, {});
  }

  if ($assetpack->minify and $path !~ /\bmin\b/ and length $$text) {
    $$text = JavaScript::Minifier::XS::minify($$text);
    $$text = "alert('Failed to minify $path')\n" unless defined $$text;
  }

  return $self;
}

sub _follow_requires {
  my ($self, $text, $path, $uniq) = @_;

  local $self->{require_js} = '';
  $$text =~ s!\brequire\s*\(\s*(["'])(.+)+\1\s*\)\s*!{ $self->_inline_module($2, $path, $uniq) }!ge;
  $$text = $self->{require_js} . $$text;
}

sub _inline_module {
  my ($self, $id, $path, $uniq) = @_;
  my $file = sprintf '%s.%s', $id, $path =~ /\.(\w+)$/ ? $1 : 'js';
  my $first = !keys %$uniq;
  my $js;

  $id =~ s!'!\\'!g;
  $self->{require_js} = 'var require=function(){}; require.modules={};' unless keys %$uniq;
  return qq[require.modules['$id'].exports] if $uniq->{$id}++;

  $js = slurp $file;
  $self->_follow_requires(\$js, $file, $uniq);
  return qq[(function(){var module={exports:{}};require.modules['$id']=module;\n$js\nreturn module.exports;})()];
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
