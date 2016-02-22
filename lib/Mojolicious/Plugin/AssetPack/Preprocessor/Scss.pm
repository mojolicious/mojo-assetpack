package Mojolicious::Plugin::AssetPack::Preprocessor::Scss;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::AssetPack::Preprocessor::Scss - Preprocessor for .scss files

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Preprocessor::Scss> is a preprocessor for
C<.scss> files. This module inherits all the functionality from
L<Mojolicious::Plugin::AssetPack::Preprocessor::Sass>.

You need either the "sass" executable or the cpan module L<CSS::Sass> to make
this module work:

  $ sudo apt-get install rubygems
  $ sudo gem install sass

  ...

  $ sudo cpanm CSS::Sass

You can force using the executable by setting the environment variable
C<ENABLE_LIBSASS_BINDINGS> to a false value.

=head2 SASS_PATH

The environment variable C<SASS_PATH> can be used to instruct this module
to search for C<@import> files in directories other than relative to the
the file containing the C<@import> statement.

Note that C<SASS_PATH> needs to hold absolute paths to work properly.

Example usage:

  local $ENV{SASS_PATH} = "/some/dir:/usr/share/other/dir";
  $app->asset("app.css" => "sass/app.scss");

It is also possible to set the L</include_paths> attribute instead of using
global variables:

  $app->asset->preprocessors->add(scss => Scss => {include_paths => [...]});
  $app->asset("app.css" => "sass/app.scss");

The final list of directories to search will be:

  1. dirname $main_sass_file
  3. $self->include_paths()
  2. split /:/, $ENV{SASS_PATH}

=head2 sass_functions

It possible to set the L</sass_functions> attribute to L<CSS::Sass>:

  $app->asset->preprocessors->add(scss => Scss => {sass_functions=> [...]});

=head2 COMPASS

Compass is an open-source CSS Authoring Framework built on top of L</sass>.
See L<http://compass-style.org/> for more information.

Installation on Ubuntu and Debian:

  $ sudo apt-get install rubygems
  $ sudo gem install compass

This module will try figure out if "compass" is required to process your
C<*.scss> files. This is done with this regexp on the top level sass file:

  m!\@import\W+compass\/!;

NOTE! Compass support is experimental and you probably have to set
C<ENABLE_LIBSASS_BINDINGS> to a false value to make it work.

You can disable compass detection by setting the environment variable
C<MOJO_ASSETPACK_NO_COMPASS> to a true value.

=cut

use Mojo::Base 'Mojolicious::Plugin::AssetPack::Preprocessor';
use Mojo::Util qw( slurp md5_sum );
use File::Basename ();
use File::Spec::Functions 'catfile';
use File::Which ();
use File::Which ();

use constant DEBUG => $ENV{MOJO_ASSETPACK_DEBUG} || 0;
use constant LIBSASS_BINDINGS => defined $ENV{ENABLE_LIBSASS_BINDINGS}
  ? $ENV{ENABLE_LIBSASS_BINDINGS}
  : eval 'require CSS::Sass;1';

my $IMPORT_RE = qr{ \@import \s+ (["']) (.*?) \1 }x;

=head1 ATTRIBUTES

=head2 executable

  $path = $self->executable;

Holds the path to the "sass" executable. Default to just "sass".

=head2 include_paths

  $self = $self->include_paths(\@paths);
  $paths = $self->include_paths;

Holds optional paths to search for where to find C<@import> files.

=head2 sass_functions

  $self->sass_functions( { 'foo($arg)' => sub { $_[0] } } );
  $functions = $self->sass_functions;

Holds optional functions for libsass's use. Must use L<CSS::Sass> 

=cut

has executable => sub { File::Which::which('sass') || 'sass' };
has include_paths => sub { [] };
has sass_functions => sub { {} };

=head1 METHODS

=head2 can_process

Returns true if L</executable> points to an actual file.

=cut

sub can_process { LIBSASS_BINDINGS || -f $_[0]->executable }

=head2 checksum

Returns the checksum for the given C<$text>, but also checks for any
C<@import> statements and includes those files in the checksum.

See L<Mojolicious::Plugin::AssetPack::Preprocessor/process>.

=cut

sub checksum {
  my ($self, $text, $path) = @_;
  my $ext           = $path =~ /\.(s[ac]ss)$/ ? $1 : $self->_extension;
  my @include_paths = $self->_include_paths($path);
  my @checksum      = md5_sum $$text;

  local $self->{checked} = $self->{checked} || {};

  while ($$text =~ /$IMPORT_RE/gs) {
    my $path = $self->_import_path(\@include_paths, split('/', $2), $ext) or next;
    warn "[AssetPack] Found \@import $path\n" if DEBUG == 2;
    $self->{checked}{$path}++ and next;
    push @checksum, $self->checksum(\slurp($path), $path);
  }

  return Mojo::Util::md5_sum(join '', @checksum);
}

=head2 process

This method use "sass" to process C<$text>.

See L<Mojolicious::Plugin::AssetPack::Preprocessor/process>.

=cut

sub process {
  my ($self, $assetpack, $text, $path) = @_;
  my @include_paths = $self->_include_paths($path);
  my $err;

  if (DEBUG) { local $" = ':'; warn "[AssetPack] SASS_PATH=@include_paths\n" }

  if (LIBSASS_BINDINGS) {
    local $ENV{SASS_PATH} = '';
    my %args = (include_paths => [@include_paths], sass_functions => $self->sass_functions);
    $args{output_style} = CSS::Sass::SASS_STYLE_COMPRESSED() if $assetpack->minify;
    $$text = CSS::Sass::sass2scss($$text) if $self->_extension eq 'sass';
    ($$text, $err, my $srcmap) = CSS::Sass::sass_compile($$text, %args);
    die $err if $err;
  }
  else {
    local $ENV{SASS_PATH} = join ':', @include_paths;
    my @cmd = ($self->executable, '--stdin');
    push @cmd, '--scss'           if $self->_extension eq 'scss';
    push @cmd, qw( -t compressed) if $assetpack->minify;
    push @cmd, qw( --compass ) if !$ENV{MOJO_ASSETPACK_NO_COMPASS} and $$text =~ m!\@import\W+compass\/!;
    $self->_run(\@cmd, $text, $text);
  }

  return $self;
}

sub _extension {'scss'}

sub _import_path {
  my ($self, $include_paths, @rel) = @_;
  my ($ext, $name, $path) = (pop @rel, pop @rel);

  for my $p (map { File::Spec->catdir($_, @rel) } @$include_paths) {
    for ("$name.$ext", "_$name.$ext", $name, "_$name") {
      my $f = catfile $p, $_;
      return $f if -f $f and -r _;
    }
  }

  if (DEBUG == 2) { local $" = '/'; warn "[AssetPack] Not found \@import @rel/$name.$ext\n" }
  return;
}

sub _include_paths {
  my ($self, $path) = @_;
  my $sass_path = $ENV{SASS_PATH} // '';
  return File::Basename::dirname($path), @{$self->include_paths}, split /:/, $sass_path;
}

sub _url {'http://sass-lang.com/install'}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
