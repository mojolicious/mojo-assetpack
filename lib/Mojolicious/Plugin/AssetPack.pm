package Mojolicious::Plugin::AssetPack;

=head1 NAME

Mojolicious::Plugin::AssetPack - Compress and convert css, less, sass and javascript files

=head1 VERSION

0.01

=head1 SYNOPSIS

In your application:

  use Mojolicious::Lite;

  plugin AssetPack => { rebuild => 1 };

  # define other preprocessors than the default detected
  app->asset->preprocessor(js => sub {
    my($self, $file) = @_;
    return JavaScript::Minifier::XS::minify($file) if $self->minify;
    return; # return undef will keep the original file
  });

  # define assets: $moniker => @real_assets
  app->asset('app.js' => '/js/foo.js', '/js/bar.js');
  app->asset('app.css' => '/css/foo.less', '/css/bar.scss', '/css/main.css');

  app->start;

In your template:

  %= asset 'app.js'
  %= asset 'app.css'

See also L</register>.

=head1 DESCRIPTION

=head2 Production mode

This plugin will compress scss, less, css and javascript with the help of
external applications on startup. The result will be one file with all the
sources combined. This file is stored in L</Packed directory>.

The actual file requested will also contain the timestamp when this server was
started. This is to help refreshing cache on change.

This is done using L</pack_javascripts> and L</pack_stylesheets>.

=head2 Development mode

This plugin will expand the input files to multiple script or link tags which
makes debugging and development easier.

This is done using L</expand_moniker>.

TIP! Make morbo watch your less/sass files as well:

  $ morbo -w lib -w templates -w public/sass

=head2 Packed directory

The output directory where all the compressed files are stored will be
"public/packed", relative to the application home:

  $app->home->rel_dir('public/packed');

=head2 Applications

=over 4

=item * less

LESS extends CSS with dynamic behavior such as variables, mixins, operations
and functions. See L<http://lesscss.org> for more details.

Installation on Ubuntu and Debian:

  $ sudo apt-get install npm
  $ sudo npm install -g less

=item * sass

Sass makes CSS fun again. Sass is an extension of CSS3, adding nested rules,
variables, mixins, selector inheritance, and more. See L<http://sass-lang.com>
for more information.

Installation on Ubuntu and Debian:

  $ sudo apt-get install rubygems
  $ sudo gem install sass

=item * yuicompressor

L<http://yui.github.io/yuicompressor> is used to compress javascript and css.

Installation on Ubuntu and Debian:

  $ sudo apt-get install npm
  $ sudo npm -g i yuicompressor

=back

=cut

use Mojo::Base 'Mojolicious::Plugin';
use Mojo::ByteStream 'b';
use Mojo::Util 'slurp';
use Fcntl qw(O_CREAT O_EXCL O_WRONLY);
use File::Spec::Functions qw( catfile );
use File::Which;

our $VERSION = '0.01';

=head1 ATTRIBUTES

=head2 minify

This is set to true if the assets should be minified.

=cut

has minify => 0;

=head1 METHODS

=head2 pack_javascripts

  $self->pack_javascripts($moniker => \@files);

This method will combine the input files to one file L</Packed directory>,
named "$moniker".

Will also run L</yuicompressor> on the input files to minify them - except if
the name contains "min". Example "jquery.min.js" will not be minified by
L</yuicompressor>.

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
      $fh->syswrite($self->_run_preprocessor($file));
    }
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
    $fh->syswrite($self->_run_preprocessor($file));
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

=head2 preprocessor

  $self->preprocessor($extension => $cb);

Define a preprocessor which is run on a given file extension.

The default preprocessor defined is described under L</Applications>.

=cut

sub preprocessor {
  my($self, $ext, $code) = @_;
  $self->{preprocessor}{$ext} = $code;
  $self;
}

=head2 register

  plugin 'AssetPack', {
    minify => $bool,
    rebuild => $bool,
  };

Will register the C<compress> helper. All arguments are optional.

"minify" will default to true if L<Mojolicious/mode> is "production".

"rebuild" can be set to true to always rebuild the compressed files when the
application is started. The default is to use the cached files.

=cut

sub register {
  my($self, $app, $config) = @_;
  my $minify = $config->{minify} // $app->mode eq 'production';
  my $helper = $config->{helper} || 'asset';

  $self->minify($minify);
  $self->_detect_default_preprocessors unless $config->{no_autodetect};

  $self->{assets} = {};
  $self->{log} = $app->log;
  $self->{out_dir} = $app->home->rel_dir('public/packed');
  $self->{static} = $app->static;

  mkdir $self->{out_dir}; # TODO: Use mkpath instead?

  if($minify and $config->{rebuild}) {
    opendir(my $DH, $self->{out_dir});
    unlink catfile $self->{out_dir}, $_ for grep { /^\w/ } readdir $DH;
  }

  $app->helper($helper => sub {
    return $self if @_ == 1;
    return $self->_asset_pack(@_) if @_ > 2;
    return $self->expand_moniker(@_) unless $minify;
    my($name, $ext) = $_[1] =~ /^(.+)\.(\w+)$/;
    return $_[0]->javascript("/packed/$name.$^T.$ext") if $ext eq 'js';
    return $_[0]->stylesheet("/packed/$name.$^T.$ext");
  });

  $app->hook(before_dispatch => sub {
    my $c = shift;
    my $url = $c->req->url;

    return unless $url->path =~ m!^\/?packed/(.+)\.(\d+)\.(\w+)$!;
    return unless $self->{assets}{"$1.$3"};
    $url->path("$1.$3");
  });
}

sub _asset_pack {
  my($self, $c, $moniker, @files) = @_;

  if($self->minify) {
    $moniker =~ /\.js/
      ? $self->pack_javascripts($moniker => \@files)
      : $self->pack_stylesheets($moniker => \@files)
      ;
  }

  $self->{assets}{$moniker} = [@files];
  $self;
}

sub _compile_css {
  my($self, $file) = @_;
  my $original = $file;

  if($file =~ s/\.(scss|less)$/.css/) {
    eval {
      my $in = $self->{static}->file($original)->path;
      (my $out = $in) =~ s/\.\w+$/.css/;
      open my $FH, '>', $out or die "Write $out: $!";
      print $FH $self->_run_preprocessor($in);
      1;
    } or do {
      $self->{log}->warn("Could not convert $original: $@");
    };
  }

  $file;
}

sub _input_files {
  my($self, $files) = @_;

  return map {
    my $file = $self->{static}->file($_);
    $file ? $file->path : $_;
  } @$files;
}

sub _detect_default_preprocessors {
  my $self = shift;

  if(my $app = which('lessc')) {
    $self->preprocessor(less => sub {
      my($self, $file) = @_;
      my @args = $self->minify ? ('-x') : ();
      open my $APP, '-|', $app => @args => $file or die "$app @args $file: $!";
      local $/; readline $APP;
    });
  }

  if(my $app = which('sass')) {
    $self->preprocessor(scss => sub {
      my($self, $file) = @_;
      my @args = $self->minify ? ('-t', 'compressed') : ();
      open my $APP, '-|', $app => @args => $file or die "$app @args $file: $!";
    });
  }

  if(my $app = which('yui-compressor') || which('yuicompressor')) {
    my $cb = sub {
      my($self, $file) = @_;
      return unless $self->minify;
      open my $APP, '-|', $app => $file or die "$app $file: $!";
      local $/; readline $APP;
    };
    $self->preprocessor(js => $cb);
    $self->preprocessor(css => $cb);
  }
}

sub _run_preprocessor {
  my($self, $file) = @_;
  my $type = $file =~ /\.(\w{2,4})/ ? $1 : 'UNKNOWN';
  my $code = $self->{preprocessor}{$type};
  my $text;

  unless($code) {
    $self->{log}->warn("Undefined preprocessor for $type");
    return "/* Undefined preprocessor for $type */";
  }

  $text = $self->$code($file);

  unless(defined $text) {
    open my $FH, '<', $file;
    local $/;
    $text = readline $FH;
  }

  return $text;
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
