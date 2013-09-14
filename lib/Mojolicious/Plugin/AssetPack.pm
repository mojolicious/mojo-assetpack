package Mojolicious::Plugin::AssetPack;

=head1 NAME

Mojolicious::Plugin::AssetPack - Pack css, scss and javascript with external tools

=head1 VERSION

0.01

=head1 DESCRIPTION

=head2 Production mode

This plugin will automatically compress scss, less, css and javascript with
the help of external applications. The result will be one file with all the
sources combined. This file is stored in L</Packed directory>.

This is done using L</pack_javascripts> and L</pack_stylesheets>.

=head2 Development mode

This plugin will expand the input files to multiple cript / link tags which
makes debugging and development easier.

This is done using L</expand_moniker>.

=head2 Packed directory

The output directory where all the compressed files are stored will be
"public/packed", relative to the application home:

  $app->home->rel_dir('public/packed');

=head1 SYNOPSIS

In your application:

  use Mojolicious::Lite;

  plugin 'AssetPack';

  # define assets: $moniker => @real_assets
  app->asset('app.js' => '/js/foo.js', '/js/bar.js');
  app->asset('app.css' => '/css/foo.less', '/css/bar.scss', '/css/main.css');

  app->start;

In your template:

  %= asset 'app.js'
  %= asset 'app.css'

See also L</register>.

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

=cut

use Mojo::Base 'Mojolicious::Plugin';
use Mojo::ByteStream 'b';
use Mojo::Util 'slurp';
use Fcntl qw(O_CREAT O_EXCL O_WRONLY);
use File::Spec::Functions qw( catfile );
use File::Which;
use constant DEBUG => $ENV{MOJO_COMPRESS_DEBUG} || 0;

our $VERSION = '0.01';
our %APPLICATIONS; # should consider internal usage, may change without warning

=head1 METHODS

=head2 pack_javascripts

  $self->pack_javascripts($moniker => \@files);

This method will combine the input files to one file L</Packed directory>,
named "$moniker".

Will also run L</yuicompressor> on the input files to minify them.

=cut

sub pack_javascripts {
  my($self, $moniker, $files) = @_;
  my $path = catfile $self->{out_dir}, $moniker;
  my $fh = IO::File->new($path, O_CREAT | O_EXCL | O_WRONLY);

  unless($fh) {
    $self->{log}->debug("$path already exists");
    return;
  }

  for my $file ($self->_input_files($files)) {
    if($file =~ /\bmin\b/) {
      $fh->syswrite(slurp $file);
    }
    else {
      $self->_pack_js($file => $fh);
    }
    $fh->syswrite("\n");
  }

  $fh->close or die "close $path: $!";
}

=head2 pack_stylesheets

  $self->pack_stylesheets($moniker => \@files);

This method will combine the input files to one file L</Packed directory>,
named "$moniker".

Will also run L</less> or L</sass> on the input files to minify them.

=cut

sub pack_stylesheets {
  my($self, $moniker, $files) = @_;
  my $path = catfile $self->{out_dir}, $moniker;
  my $fh = IO::File->new($path, O_CREAT | O_EXCL | O_WRONLY);

  unless($fh) {
    $self->{log}->debug("$path already exists");
    return;
  }

  for my $file ($self->_input_files($files)) {
    if($file =~ /\.(scss|less)$/) {
      my $method = "_pack_$1";
      $self->$method($file => $fh);
    }
    else {
      $fh->syswrite(slurp $file);
    }
  }

  $fh->close or die "close $path: $!";
}

=head2 expand_moniker

  $bytestream = $self->expand_moniker($c, $moniker);

This method will return one tag for each asset defined by the "$moniker".

Will also run L</less> or L</sass> on the files to convert them to css, which
the browser understand.

The returning bytestream will contain style or script tags.

=cut

sub expand_moniker {
  my($self, $c, $moniker) = @_;
  my $files = $self->{assets}{$moniker};

  if(!$files) {
    return b "<!-- Could not expand_moniker $moniker -->";
  }
  elsif($moniker =~ /\.js/) {
    return b join '', map { $c->javascript($_) } @$files;
  }
  else {
    return b join '', map { $c->stylesheet($self->_compile_css($_)) } @$files;
  }
}

=head2 find_external_apps

This method is used to find the L</APPLICATIONS>. It will look for the apps
using L<File::Which> in this order: lessc, less, sass, yui-compressor,
yuicompressor.

=cut

sub find_external_apps {
  my($self, $app, $config) = @_;

  $APPLICATIONS{less} = $config->{less} || which('lessc') || which('less');
  $APPLICATIONS{sass} = $config->{sass} || which('sass');
  $APPLICATIONS{yuicompressor} = $config->{yuicompressor} || which('yui-compressor') || which('yuicompressor');

  for(keys %APPLICATIONS) {
    $APPLICATIONS{$_} and next;
    $app->log->warn("Could not find application for $_");
  }
}

=head2 register

  plugin 'AssetPack', {
    enable => $bool,
    reset => $bool,
    yuicompressor => '/path/to/yuicompressor',
    less => '/path/to/lessc',
    sass => '/path/to/sass',
  };

Will register the C<compress> helper. All arguments are optional.

"enable" will default to COMPRESS_ASSETS environment variable or set to true
if L<Mojolicious/mode> is "production".

"reset" can be set to true to always rebuild the javascript one the first
request that hit the server.

=cut

sub register {
  my($self, $app, $config) = @_;
  my $enable = $config->{enable} // $ENV{COMPRESS_ASSETS} // $app->mode eq 'production';

  $self->find_external_apps($app, $config);

  $self->{assets} = {};
  $self->{log} = $app->log;
  $self->{out_dir} = $app->home->rel_dir('public/packed');
  $self->{static} = $app->static;

  mkdir $self->{out_dir}; # TODO: Use mkpath instead?

  if($enable and $config->{reset}) {
    opendir(my $DH, $self->{out_dir});
    unlink catfile $self->{out_dir}, $_ for grep { /^\w/ } readdir $DH;
  }

  $app->helper(asset => sub {
    return $self->_asset_pack(@_) if @_ > 2;
    return $self->expand_moniker(@_) unless $enable;
    my($name, $ext) = $_[1] =~ /^(.+)\.(\w+)$/;
    return $_[0]->javascript("/packed/$name.$^T.$ext") if $ext eq 'js';
    return $_[0]->stylesheet("/packed/$name.$^T.$ext");
  });
}

sub _asset_pack {
  my($self, $c, $moniker, @files) = @_;

  $moniker =~ /\.js/
    ? $self->pack_javascripts($moniker => \@files)
    : $self->pack_stylesheets($moniker => \@files)
    ;

  $self->{assets}{$moniker} = [@files];
  $self;
}

sub _compile_css {
  my($self, $file) = @_;

  if($file =~ /\.(scss|less)$/) {
    eval {
      my $in = $self->{static}->file($file)->path;
      (my $out = $in) =~ s/\.(\w+)$/.css/;
      my $type = $1 eq 'less' ? 'less' : 'sass';
      warn "system $APPLICATIONS{$type} $in $out\n" if DEBUG;
      system $APPLICATIONS{$type} => $in => $out;
      $file =~ s/\.(\w+)$/.css/;
    } or do {
      $self->{log}->warn("Could not convert $file: $@");
    };
  }

  $file;
}

sub _pack_js {
  my($self, $in, $OUT) = @_;

  open my $APP, '-|', $APPLICATIONS{yuicompressor} => $in or die "$APPLICATIONS{yuicompressor} $in: $!";
  print $OUT $_ while <$APP>;
}

sub _pack_less {
  my($self, $in, $OUT) = @_;

  open my $APP, '-|', $APPLICATIONS{less} => -x => $in or die "$APPLICATIONS{less} -x $in: $!";
  print $OUT $_ while <$APP>;
}

sub _pack_scss {
  my($self, $in, $OUT) = @_;

  open my $APP, '-|', $APPLICATIONS{sass} => -t => 'compressed' => $in or die "$APPLICATIONS{sass} -t compressed $in: $!";
  print $OUT $_ while <$APP>;
}

sub _input_files {
  my($self, $files) = @_;

  return map {
    my $file = $self->{static}->file($_);
    $file ? $file->path : $_;
  } @$files;
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
