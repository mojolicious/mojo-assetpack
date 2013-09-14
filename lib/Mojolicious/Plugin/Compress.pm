package Mojolicious::Plugin::Compress;

=head1 NAME

Mojolicious::Plugin::Compress - Compress css, scss and javascript with external tools

=head1 VERSION

0.01

=head1 DESCRIPTION

This plugin will automatically compress scss, less, css and javascript with
the help of external application. The result will be one file with all the
sources combined.

=head1 APPLICATIONS

=head2 less

=head2 sass

=head2 yuicompressor

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

=cut

use Mojo::Base 'Mojolicious::Plugin';
use Mojo::ByteStream 'b';
use Mojo::Util qw/ md5_sum slurp /;
use File::Spec::Functions qw/ catfile tmpdir /;
use File::Which;
use constant DEBUG => $ENV{MOJO_COMPRESS_DEBUG} || 0;

our $VERSION = '0.01';
our %APPLICATIONS; # should consider internal usage, may change without warning

=head1 ATTRIBUTES

=head2 out_dir

Defaults to "compressed" in the first search path for static files.

=cut

has out_dir => '';

=head1 METHODS

=head2 register

Will register the C<compress> helper.

=cut

sub register {
  my($self, $app, $config) = @_;
  my $enable = $config->{enable} // $ENV{COMPRESS_ASSETS} // $app->mode eq 'production';

  $self->_find_external_apps($app, $config);
  $self->out_dir($config->{out_dir} || $app->home->rel_dir('public/compressed'));

  mkdir $self->out_dir; # TODO: Use mkpath instead?

  if($enable) {
    $app->helper(compress => sub { $self->_compress_files(@_) });
  }
  else {
    $app->log->debug('Mojolicious::Plugin::Compress will expand file list');
    $app->helper(compress => sub { $self->_expand_files(@_) });
  }
}

sub _abs_to_rel {
  my($self, $c, $out) = @_;

  for my $p (@{ $c->app->static->paths }) {
    return $out if $out =~ s!^$p!!;
  }
  
  die "$out is not found in static paths";
}

sub _find_external_apps {
  my($self, $app, $config) = @_;

  $APPLICATIONS{less} = $config->{less} || which('lessc') || which('less');
  $APPLICATIONS{scss} = $config->{sass} || which('sass');
  $APPLICATIONS{js} = $config->{yuicompressor} || which('yui-compressor') || which('yuicompressor');

  for(keys %APPLICATIONS) {
    $APPLICATIONS{$_} and next;
    $app->log->warn("Could not find application for $_");
  }
}

sub _compress_files {
  my($self, $c, @files) = @_;
  my $type = $files[0] =~ /\.(js|css|scss|less)$/ ? $1 : '';

  if($type eq 'js') {
    return $self->_compress_javascripts($c, @files);
  }
  else {
    return $self->_compress_stylesheets($c, @files);
  }
}

sub _compress_javascripts {
  my($self, $c, @files) = @_;
  my $static = $c->app->static;
  my $file = md5_sum(join '', @files) .'.js';
  my $out = catfile $self->out_dir, $file;
  my $tmp = catfile tmpdir(), $file;

  unless(-e $out) {
    open my $OUT, '>', $out or die "Write $out: $!";

    for my $file (@files) {
      my $in = $static->file($file)->path;
      system $APPLICATIONS{js} => $in => -o => $tmp;
      print $OUT slurp $tmp if -e $tmp;
    }

    unlink $tmp if -e $tmp;
  }

  return $c->javascript($self->_abs_to_rel($c, $out));
}

sub _compress_stylesheets {
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
      system $APPLICATIONS{$1} => $in => $tmp;
      print $OUT slurp $tmp if -e $tmp;
    }

    unlink $tmp if -e $tmp;
  }

  return $c->stylesheet($self->_abs_to_rel($c, $out));
}

sub _convert_file {
  my($self, $c, $file) = @_;

  if($file =~ /\.(scss|less)$/) {
    eval {
      my $in = $c->app->static->file($file)->path;
      (my $out = $in) =~ s/\.(\w+)$/.css/;
      warn "$APPLICATIONS{$1} $in $out" if DEBUG;
      system $APPLICATIONS{$1} => $in => $out;
      $file =~ s/\.(\w+)$/.css/;
    } or do {
      $c->app->log->warn("Could not convert $file: $@");
    };
  }

  $file;
}

sub _expand_files {
  my($self, $c, @files) = @_;
  my $type = $files[0] =~ /\.(js|css|scss|less)$/ ? $1 : '';

  if($type eq 'js') {
    return b join '', map { $c->javascript($_) } @files;
  }
  else {
    return b join '', map { $c->stylesheet($self->_convert_file($c, $_)) } @files;
  }
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
