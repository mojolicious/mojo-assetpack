package Mojolicious::Plugin::AssetPack::Preprocessor::JavaScript;

=head1 NAME

Mojolicious::Plugin::AssetPack::Preprocessor::JavaScript - Preprocessor for JavaScript

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Preprocessor::JavaScript> is a preprocessor for
C<.js> files.

JavaScript is minified using L<JavaScript::Minifier::XS>. This module is
optional and must be installed manually.

NOTE! L<JavaScript::Minifier::XS> might be replaced with something better.

=head2 require()

L<nodejs|http://nodejs.org/api/modules.html> support modules. This system
is very handy, since it allows chunks of JavaScript code to be insolated in
a closure. L<Mojolicious::Plugin::AssetPack> provides a naive implementation
of this module system, allowing you to write this code:

  // foo.js
  var circle = require('./circle.js');
  console.log('The area of a circle of radius 4 is ' + circle.area(4));

  // circle.js
  var PI = Math.PI;
  module.exports.area = function(r) { return PI * r * r; };
  module.exports.circumference = function(r) { return 2 * PI * r; };

The C<circle.js> code is isolated from the C<foo.js> code, meaning the C<PI>
variable is not accessible. On the other hand, the C<module.exports> variable
will be the return value from C<require()>.

=cut

use Mojo::Base 'Mojolicious::Plugin::AssetPack::Preprocessor';
use Mojo::Util;
use Cwd ();
use File::Basename 'dirname';
use File::Spec;
use JavaScript::Minifier::XS;

require Mojolicious::Plugin::AssetPack::Preprocessors;    # Mojolicious::Plugin::AssetPack::Preprocessors::CWD

$ENV{NODE_PATH} ||= '';

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

sub _default_ext {'js'}

sub _follow_requires {
  my ($self, $text, $path, $uniq) = @_;

  local $self->{require_js} = '';
  $$text =~ s!\brequire\s*\(\s*(["'])(.+)+\1\s*\)\s*!{ $self->_inline_module($2, $path, $uniq) }!ge;
  $$text = $self->{require_js} . $$text;
}

sub _inline_module {
  my ($self, $file, $path, $uniq) = @_;
  my $id = $file;

  $id =~ s!'!\\'!g;
  $id =~ s!^\./!!g;
  $self->{require_js} = 'var require=function(){}; require.modules={};' unless keys %$uniq;
  return qq[require.modules['$id'].exports] if $uniq->{$id}++;

  my $js = $self->_slurp($file, $path =~ /\.(\w+)$/ ? $1 : $self->_default_ext);
  $self->_follow_requires(\$js, $file, $uniq);
  return
    qq[(function(){var exports={};var module={exports:exports};require.modules['$id']=module;\n$js\nreturn module.exports;})()];
}

sub _slurp {
  my ($self, $file, $ext) = @_;
  my @path = (Cwd::getcwd, split /:/, $ENV{NODE_PATH});

  for my $mod_dir (@path) {
    for ($file, "$file.$ext") {
      my $abs_path = File::Spec->catfile($mod_dir, $_);
      return Mojo::Util::slurp($abs_path) if -e $abs_path;
    }
  }

  die "Could not find JavaScript module '$file' in @path.";
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
