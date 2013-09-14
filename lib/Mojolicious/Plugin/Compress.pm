package Mojolicious::Plugin::Compress;

=head1 NAME

Mojolicious::Plugin::Compress - Compress css, scss and javascript with external tools

=head1 VERSION

0.01

=head1 DESCRIPTION

In production mode:

This plugin will automatically compress scss, less, css and javascript with
the help of external application. The result will be one file with all the
sources combined.

This is done using L</compress_javascripts> and L</compress_stylesheets>.

In development mode:

This plugin will expand the input files to multiple javascript / link tags
which makes debugging easier.

This is done using L</expand_files>.

=head1 APPLICATIONS

=head2 less

LESS extends CSS with dynamic behavior such as variables, mixins, operations
and functions. See L<http://lesscss.org> for more details.

Installation on Ubuntu and Debian:

  $ sudo apt-get install npm
  $ sudo npm install -g less

=head2 sass

Sass makes CSS fun again. Sass is an extension of CSS3, adding nested rules,
variables, mixins, selector inheritance, and more. See L<http://sass-lang.com>
for more information.

Installation on Ubuntu and Debian:

  $ sudo apt-get install rubygems
  $ sudo gem install sass

=head2 yuicompressor

L<http://yui.github.io/yuicompressor> is used to compress javascript and css.

Installation on Ubuntu and Debian:

  $ sudo apt-get install npm
  $ sudo npm -g i yuicompressor

=head1 SYNOPSIS

In your application:

  use Mojolicious::Lite;
  plugin 'Compress';
  app->start;

In your template:

  %= compress '/js/jquery.min.js', '/js/app.js';
  %= compress '/less/reset.less', '/sass/helpers.scss', '/css/app.css';

NOTE! You need to have one line for each type, meaning you cannot combine
javascript and css sources on one line.

See also L</register>.

=cut

use Mojo::Base 'Mojolicious::Plugin';
use Mojo::ByteStream 'b';
use Mojo::Util qw/ md5_sum slurp /;
use File::Spec::Functions qw/ catfile tmpdir /;
use File::Which;
use constant DEBUG => $ENV{MOJO_COMPRESS_DEBUG} || 0;

our $VERSION = '0.01';
our %APPLICATIONS; # should consider internal usage, may change without warning

sub _system {
  warn "@_" if DEBUG;
  system @_;
}

=head1 ATTRIBUTES

=head2 out_dir

Defaults to "compressed" in the first search path for static files.

=cut

has out_dir => '';

=head1 METHODS

=head2 compress_javascripts

  $bytestream = $self->compress_javascripts($c, @rel_files);

This method will compress the input files to a file in the L</out_dir>
with the name of the MD5 sum of the C<@files>.

Will also run L</yuicompressor> on the input files to minify them.

The returning bytestream will contain a javascript tag.

=cut

sub compress_javascripts {
  my($self, $c, @files) = @_;
  my $static = $c->app->static;
  my $file = md5_sum(join '', @files) .'.js';
  my $out = catfile $self->out_dir, $file;
  my $tmp = catfile tmpdir(), $file;

  unless(-e $out) {
    open my $OUT, '>', $out or die "Write $out: $!";

    for my $file (@files) {
      my $in = $static->file($file)->path;
      _system $APPLICATIONS{js} => $in => -o => $tmp;
      print $OUT slurp $tmp if -e $tmp;
    }

    unlink $tmp if -e $tmp;
  }

  return $c->javascript($self->_abs_to_rel($c, $out));
}

=head2 compress_stylesheets

  $bytestream = $self->compress_stylesheets($c, @rel_files);

This method will compress the input files to a file in the L</out_dir>
with the name of the MD5 sum of the C<@files>.

Will also run L</less> or L</sass> on the input files to minify them.

The returning bytestream will contain a style tag.

=cut

sub compress_stylesheets {
  my($self, $c, @files) = @_;
  my $static = $c->app->static;
  my $file = md5_sum(join '', @files) .'.css';
  my $out = catfile $self->out_dir, $file;
  my $tmp = catfile tmpdir(), $file;

  unless(-e $out) {
    open my $OUT, '>', $out or die "Write $out: $!";

    for my $file (@files) {
      $file =~ /\.(scss|less)$/ or next;
      my $in = $static->file($file)->path;
      _system $APPLICATIONS{$1} => $in => $tmp;
      print $OUT slurp $tmp if -e $tmp;
    }

    unlink $tmp if -e $tmp;
  }

  return $c->stylesheet($self->_abs_to_rel($c, $out));
}

=head2 expand_files

  $bytestream = $self->expand_files($c, @rel_files);

This method will return one tag pr. input file which holds the uncompressed
version of the sources.

Will also run L</less> or L</sass> on the input files to convert them to
css, which the browser understand.

The returning bytestream will contain style or javascript tags.

=cut

sub expand_files {
  my($self, $c, @files) = @_;
  my $type = $files[0] =~ /\.(js|css|scss|less)$/ ? $1 : '';

  if($type eq 'js') {
    return b join '', map { $c->javascript($_) } @files;
  }
  else {
    return b join '', map { $c->stylesheet($self->_convert_file($c, $_)) } @files;
  }
}

=head2 find_external_apps

This method is used to find the L</APPLICATIONS>. It will look for the apps
usin L<File::Which> in this order: lessc, less, sass, yui-compressor,
yuicompressor.

=cut

sub find_external_apps {
  my($self, $app, $config) = @_;

  $APPLICATIONS{less} = $config->{less} || which('lessc') || which('less');
  $APPLICATIONS{scss} = $config->{sass} || which('sass');
  $APPLICATIONS{js} = $config->{yuicompressor} || which('yui-compressor') || which('yuicompressor');

  for(keys %APPLICATIONS) {
    $APPLICATIONS{$_} and next;
    $app->log->warn("Could not find application for $_");
  }
}

=head2 register

  plugin 'Compress', {
    enable => $bool,
    out_dir => '/abs/path/to/app/public/dir',
    less => '/path/to/lessc',
    sass => '/path/to/sass',
    js => '/path/to/yuicompressor',
  };

Will register the C<compress> helper. All arguments are optional.

"enable" will default to COMPRESS_ASSETS environment variable or set to true
if L<Mojolicious/mode> is "production".

=cut

sub register {
  my($self, $app, $config) = @_;
  my $enable = $config->{enable} // $ENV{COMPRESS_ASSETS} // $app->mode eq 'production';

  $self->find_external_apps($app, $config);
  $self->out_dir($config->{out_dir} || $app->home->rel_dir('public/compressed'));

  mkdir $self->out_dir; # TODO: Use mkpath instead?

  if($enable) {
    $app->helper(compress => sub { 
      my($c, @files) = @_;
      my $type = $files[0] =~ /\.(js|css|scss|less)$/ ? $1 : '';

      if($type eq 'js') {
        return $self->compress_javascripts($c, @files);
      }
      else {
        return $self->compress_stylesheets($c, @files);
      }
    });
  }
  else {
    $app->log->debug('Mojolicious::Plugin::Compress will expand file list');
    $app->helper(compress => sub { $self->expand_files(@_) });
  }
}

sub _abs_to_rel {
  my($self, $c, $out) = @_;

  for my $p (@{ $c->app->static->paths }) {
    return $out if $out =~ s!^$p!!;
  }
  
  die "$out is not found in static paths";
}

sub _convert_file {
  my($self, $c, $file) = @_;

  if($file =~ /\.(scss|less)$/) {
    eval {
      my $in = $c->app->static->file($file)->path;
      (my $out = $in) =~ s/\.(\w+)$/.css/;
      _system $APPLICATIONS{$1} => $in => $out;
      $file =~ s/\.(\w+)$/.css/;
    } or do {
      $c->app->log->warn("Could not convert $file: $@");
    };
  }

  $file;
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
