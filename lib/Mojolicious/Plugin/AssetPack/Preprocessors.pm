package Mojolicious::Plugin::AssetPack::Preprocessors;

=head1 NAME

Mojolicious::Plugin::AssetPack::Preprocessors - Holds preprocessors

=cut

use Mojo::Base 'Mojo::EventEmitter';
use Cwd;
use File::Basename;
use File::Which;
use IPC::Run3;

our $VERSION = '0.01';

=head1 METHODS

=head2 add

  $self->add($extension => $cb);

Define a preprocessor which is run on a given file extension. These
preprocessors will be chained. The callbacks will be called in the order they
where added.

The default preprocessor defined is described under L</detect>.

=cut

sub add { shift->on(@_) }

=head2 detect

Will add the following preprocessors, if they are available:

=over 4

=item * less

LESS extends CSS with dynamic behavior such as variables, mixins, operations
and functions. See L<http://lesscss.org> for more details.

Installation on Ubuntu and Debian:

  $ sudo apt-get install npm
  $ sudo npm install -g less

=item * scss

Sass makes CSS fun again. Sass is an extension of CSS3, adding nested rules,
variables, mixins, selector inheritance, and more. See L<http://sass-lang.com>
for more information. Supports both F<*.scss> and F<*.sass> syntax variants.

Installation on Ubuntu and Debian:

  $ sudo apt-get install rubygems
  $ sudo gem install sass

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

  if(my $app = which('lessc')) {
    $self->map_type(less => 'css');
    $self->add(less => sub {
      my($assetpack, $text, $file) = @_;
      run3([$app, '-', $assetpack->minify ? ('-x') : ()], $text, $text);
    });
  }
  if(my $app = which('sass')) {
    $self->map_type(scss => 'css');
    $self->add(scss => sub {
      my($assetpack, $text, $file) = @_;
      my $include_dir = dirname $file;
      my $err;
      if (grep("compass",$text))
      {
        $assetpack->{log}->warn("compass detected!!!!!");
        if(which('compass')) 
        {
          run3([$app,$assetpack->minify ? ('-t', 'compressed') : (),'--stdin','--scss','--compass',], $text, $text,\$err);
          if ($err) {
            $assetpack->{log}->warn("Error processing $file: $err");
          }
        }else
        {
          $assetpack->{log}->info("Error: import of compass modules in $file while the compass command is not found."); 
        }
      }else
      {
        run3([$app, '-I', $include_dir, '--stdin', '--scss', $assetpack->minify ? ('-t', 'compressed') : ()], $text, $text,\$err);
        if ($err) {
          $assetpack->{log}->warn("Error processing $file: $err");
        }
      } 
    });
    $self->map_type(sass => 'css');
    $self->add(sass => sub {
      my($assetpack, $text, $file) = @_;
      my $include_dir = dirname $file;
      run3([$app, '-I', $include_dir, '--stdin', $assetpack->minify ? ('-t', 'compressed') : ()], $text, $text);
    });
  }
  if(my $app = which('coffee')) {
    $self->map_type(coffee => 'js');
    $self->add(coffee => sub {
      my($assetpack, $text, $file) = @_;
      my $err;
      run3([$app, '--compile', '--stdio'], $text, $text, \$err);
      if ($assetpack->minify && eval 'require JavaScript::Minifier::XS; 1') {
        $$text = JavaScript::Minifier::XS::minify($$text);
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
      $$text = JavaScript::Minifier::XS::minify($$text) if $assetpack->minify and $file !~ /\bmin\b/;
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

  eval {
    chdir dirname $filename;
    $_->($assetpack, $text, $filename) for @{ $self->subscribers($extension) };
    1;
  } or do {
    $self->emit(error => "process $filename: $@");
  };

  chdir $old_dir;

  $self;
}

=head2 map_type

  $self = $self->map_type($from => $to);
  $to = $self->map_type($from);

Method used to map one file type that should be transformed to another file
type. Example:

  $self->map_type(coffee => "js");

=cut

sub map_type {
  return $_[0]->{extensions}{$_[1]} || '' if @_ == 2;
  $_[0]->{extensions}{$_[1]} = $_[2];
  return $_[0];
}

=head2 remove

  $self->remove($extension);
  $self->remove($extension => $cb);

This method will remove all preprocessors defined for an extension, or just a
given C<$cb>.

=cut

sub remove { shift->unsubscribe(@_) }

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
