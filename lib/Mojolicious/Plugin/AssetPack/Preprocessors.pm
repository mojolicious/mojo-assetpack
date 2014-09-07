package Mojolicious::Plugin::AssetPack::Preprocessors;

=head1 NAME

Mojolicious::Plugin::AssetPack::Preprocessors - Holds preprocessors

=cut

use Mojo::Base 'Mojo::EventEmitter';
use Mojo::Util ();
use Mojolicious::Plugin::AssetPack::Preprocessor;
use Cwd;
use File::Basename;
use File::Which;
use IPC::Run3 ();
use constant DEBUG => $ENV{MOJO_ASSETPACK_DEBUG} || 0;

our $VERSION = '0.01';

=head1 METHODS

=head2 add

  $self->add($extension => $object);

  $self->add($extension => sub {
    my ($assetpack, $text, $file) = @_;
    $$text =~ s/foo/bar/ if $file =~ /baz/ and $assetpack->minify;
  });

Define a preprocessor which is run on a given file extension. These
preprocessors will be chained. The callbacks will be called in the order they
where added.

The default preprocessor defined is described under L</detect>.

In case of C<$object>, the object need to be able to have the C<process()>
method.

=cut

sub add {
  my ($self, $type, $arg) = @_;

  # back compat
  if (ref $arg eq 'CODE') {
    $arg = Mojolicious::Plugin::AssetPack::Preprocessor->new(processor => $arg);
  }

  $self->on($type => $arg);
}

=head2 checksum

  $str = $self->checksum($extension => \$text, $filename);

=cut

sub checksum {
  my($self, $extension, $text, $filename) = @_;
  my $old_dir = getcwd;
  my $err = '';
  my @checksum;

  local $@;

  eval {
    chdir dirname $filename if $filename;
    push @checksum, $_->checksum($text, $filename) for @{ $self->subscribers($extension) };
    1;
  } or do {
    $err = $@ || "AssetPack failed with unknown error while processing $filename.\n";
  };

  chdir $old_dir;
  die $err if $err;
  return @checksum == 1 ? $checksum[0] : Mojo::Util::md5_sum(join '', @checksum);
}

=head2 detect

Will add the following preprocessors, if they are available:

=over 4

=item * jsx

JSX is a JavaScript XML syntax transform recommended for use with
L<React|http://facebook.github.io/react>. See
L<http://facebook.github.io/react/docs/jsx-in-depth.html> for more information.

Installation on Ubuntu and Debian:

  $ sudo apt-get install npm
  $ npm install -g react-tools

=item * less

LESS extends CSS with dynamic behavior such as variables, mixins, operations
and functions. See L<http://lesscss.org> for more details.

Installation on Ubuntu and Debian:

  $ sudo apt-get install npm
  $ sudo npm install -g less

=item * sass

Sass makes CSS fun again. Sass is an extension of CSS3, adding nested rules,
variables, mixins, selector inheritance, and more. See L<http://sass-lang.com>
for more information. Supports both F<*.scss> and F<*.sass> syntax variants.

Installation on Ubuntu and Debian:

  $ sudo apt-get install rubygems
  $ sudo gem install sass

=item * compass

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

=item * js

Javascript is minified using L<JavaScript::Minifier::XS>. This module is
optional and must be installed manually.

EXPERIMENTAL! Not sure if this is the best minifier.

=item * css

CSS is minified using L<CSS::Minifier::XS>. This module is optional and must
be installed manually.

EXPERIMENTAL! Not sure if this is the best minifier.

=item * coffee

CoffeeScript is a little language that compiles into JavaScript. See
L<http://coffeescript.org> for more information.

Installation on Ubuntu and Debian:

  $ npm install -g coffee-script

=back

=cut

sub detect {
  my $self = shift;

  require Mojolicious::Plugin::AssetPack::Preprocessor::Sass;
  $self->add(sass => Mojolicious::Plugin::AssetPack::Preprocessor::Sass->new);

  require Mojolicious::Plugin::AssetPack::Preprocessor::Scss;
  $self->add(scss => Mojolicious::Plugin::AssetPack::Preprocessor::Scss->new);

  if(my $app = which('jsx')) {
    $self->add(jsx => sub {
      my($assetpack, $text, $file) = @_;
      $self->_run(['jsx'], $text, $text); # TODO: Add --follow-requires ?
      _js_minify($text, $file) if $assetpack->minify;
    });
  }
  if(my $app = which('lessc')) {
    $self->add(less => sub {
      my($assetpack, $text, $file) = @_;
      $self->_run([$app, '-', $assetpack->minify ? ('-x') : ()], $text, $text);
    });
  }
  if(my $app = which('coffee')) {
    $self->add(coffee => sub {
      my($assetpack, $text, $file) = @_;
      my $err;
      $self->_run([$app, '--compile', '--stdio'], $text, $text, \$err);
      if ($assetpack->minify && eval 'require JavaScript::Minifier::XS; 1') {
        _js_minify($text, $file) if $assetpack->minify;
      }
      if ($err) {
        $assetpack->{log}->warn("Error processing $file: $err");
      }
      $$text;
    });
  }
  if(eval 'require JavaScript::Minifier::XS; 1') {
    $self->add(js => sub {
      my($assetpack, $text, $file) = @_;
      _js_minify($text, $file) if $assetpack->minify and $file !~ /\bmin\b/;
    });
  }
  if(eval 'require CSS::Minifier::XS; 1') {
    $self->add(css => sub {
      my($assetpack, $text, $file) = @_;
      $$text = CSS::Minifier::XS::minify($$text) if $assetpack->minify;
    });
  }
}

=head2 process

  $self->process($extension => $assetpack, \$text, $filename);

Will run the preprocessor callbacks added by L</add>. The callbacks will be
called with the C<$assetpack> object as the first argument.

=cut

sub process {
  my($self, $extension, $assetpack, $text, $filename) = @_;
  my $old_dir = getcwd;
  my $err = '';

  local $@;

  eval {
    chdir dirname $filename;
    $_->($_, $assetpack, $text, $filename) for @{ $self->subscribers($extension) };
    1;
  } or do {
    $err = $@ || "AssetPack failed with unknown error while processing $filename.\n";
  };

  chdir $old_dir;
  die $err if $err;
  $self;
}

=head2 map_type

DEPRECATED: The mapping is already done based on input files.

=head2 remove

  $self->remove($extension);
  $self->remove($extension => $cb);

This method will remove all preprocessors defined for an extension, or just a
given C<$cb>.

=cut

sub remove { shift->unsubscribe(@_) }

sub _js_minify {
  my ($text, $file) = @_;
  $$text = JavaScript::Minifier::XS::minify($$text);
  $$text = '' unless defined $$text;
}

sub _run {
  my ($class, @args) = @_;
  local ($?, $@, $!);
  warn "[ASSETPACK] \$ @{ $args[0] }\n" if DEBUG;
  eval { IPC::Run3::run3(@args); };
  return $class unless $?;
  chomp $@ if $@;
  die sprintf "AssetPack failed to run '%s'. exit_code=%s (%s)\n", join(' ', @{ $args[0] }), $? <= 0 ? $? : $? >> 8, $@ || $?;
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
