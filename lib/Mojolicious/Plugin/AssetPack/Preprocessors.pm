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
for more information.

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

=back

=cut

sub detect {
  my $self = shift;

  if(my $app = which('lessc')) {
    $self->add(less => sub {
      my($assetpack, $text, $file) = @_;
      run3([$app, '-', $assetpack->minify ? ('-x') : ()], $text, $text);
    });
  }
  if(my $app = which('sass')) {
    $self->add(scss => sub {
      my($assetpack, $text, $file) = @_;
      run3([$app, '--stdin', '--scss', $assetpack->minify ? ('-t', 'compressed') : ()], $text, $text);
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
  my $self = shift;
  my $old_dir = getcwd;

  eval {
    chdir dirname $_[3];
    $_->(@_) for @{ $self->subscribers(shift) };
    1;
  } or do {
    $self->emit(error => "process $_[3]: $@");
  };

  chdir $old_dir;

  $self;
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
