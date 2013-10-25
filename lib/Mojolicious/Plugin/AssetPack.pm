package Mojolicious::Plugin::AssetPack;

=head1 NAME

Mojolicious::Plugin::AssetPack - Compress and convert css, less, sass and javascript files

=head1 VERSION

0.0201

=head1 SYNOPSIS

In your application:

  use Mojolicious::Lite;

  plugin AssetPack => { rebuild => 1 };

  # add a preprocessor
  app->asset->preprocessors->add(js => sub {
    my($assetpack, $text, $file) = @_;
    $$text = "// yikes!\n" if 5 < rand 10;
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

The files in the packed directory will have a checksum added to the
filename which will ensure broken browsers request a new version once the
file is changed. Example:

  <script src="/packed/app-ed6d968e39843a556dbe6dad8981e3e0.js">

This is done using L</process>.

=head2 Development mode

This plugin will expand the input files to multiple script or link tags which
makes debugging and development easier.

This is done using L</expand>.

TIP! Make morbo watch your less/sass files as well:

  $ morbo -w lib -w templates -w public/sass

=head2 Packed directory

The output directory where all the compressed files are stored will be
"public/packed", relative to the application home:

  $app->home->rel_dir('public/packed');

=head2 Preprocessors

This library tries to find default preprocessors for less, scss, js and css.

NOTE! The preprocessors require optional dependencies to function properly.
Check out L<Mojolicious::Plugin::AssetPack::Preprocessors/detect> for more
details.

=cut

use Mojo::Base 'Mojolicious::Plugin';
use Mojo::ByteStream 'b';
use Mojo::Util qw( md5_sum slurp spurt );
use Mojolicious::Plugin::AssetPack::Preprocessors;
use Fcntl qw( O_CREAT O_EXCL O_WRONLY );
use File::Basename qw( basename );
use File::Spec::Functions qw( catfile );

our $VERSION = '0.0201';

=head1 ATTRIBUTES

=head2 minify

Set this to true if the assets should be minified.

=cut

has minify => 0;

=head2 preprocessors

Holds a L<Mojolicious::Plugin::AssetPack::Preprocessors> object.

=cut

has preprocessors => sub { Mojolicious::Plugin::AssetPack::Preprocessors->new };

=head2 rebuild

Set this to true if the assets should created, even though they exist.

=cut

has rebuild => 0;

=head1 METHODS

=head2 add

  $self->add($moniker => @rel_files);

Used to define new assets aliases. This method is called when the C<asset()>
helper is called on the app.

=cut

sub add {
  my($self, $moniker, @files) = @_;

  $self->{assets}{$moniker} = [@files];
  $self->process($moniker) if $self->minify;
  $self;
}

=head2 expand

  $bytestream = $self->expand($c, $moniker);

This method will return one tag for each asset defined by the "$moniker".

Will also run L</less> or L</sass> on the files to convert them to css, which
the browser understand.

The returning bytestream will contain style or script tags.

=cut

sub expand {
  my($self, $c, $moniker) = @_;
  my $files = $self->{assets}{$moniker};

  if(!$files) {
    return b "<!-- Could not expand $moniker -->";
  }
  elsif($moniker =~ /\.js/) {
    return b join "\n", map { $c->javascript($_) } @$files;
  }
  else {
    return b join "\n", map { $c->stylesheet($self->_compile_css($_)) } @$files;
  }
}

=head2 process

  $self->process($moniker);

This method use L<Mojolicious::Plugin::AssetPack::Preprocessors/process> to
convert and/or minify the sources pointed at by C<$moniker>.

The result file will be stored in L</Packed directory>.

=cut

sub process {
  my($self, $moniker) = @_;
  my $assets = $self->{assets}{$moniker};
  my $extension = $moniker =~ /\.(\w{1,4})$/ ? $1 : '';
  my $mode = $self->rebuild ? O_CREAT | O_WRONLY : O_CREAT | O_EXCL | O_WRONLY;
  my $out_file = catfile $self->{out_dir}, $moniker;
  my $doc = '';
  my $fh;

  unless($self->preprocessors->has_subscribers($extension)) {
    $self->{log}->warn("No preprocessors defined for $moniker");
    $self->_find_processed($moniker);
    return;
  }
  unless($fh = IO::File->new($out_file, $mode)) {
    $self->{log}->debug("Could not write $out_file: $!");
    $self->_find_processed($moniker);
    return;
  }

  for(@$assets) {
    my $file = $self->{static}->file($_); # return undef if the file does not exist
    my $text;

    $file = $file ? $file->path : $_;
    $text = slurp $file;
    $self->preprocessors->process($extension, $self, \$text, $file);
    $doc .= $text;
  }

  $fh->truncate(0);
  $fh->syswrite($doc);
  $fh->close or die "close $out_file: $!";
  $self->_remove_processed($moniker) if $self->{cleanup};
  $self->_rename_processed($moniker, md5_sum $doc);
}

=head2 register

  plugin 'AssetPack', {
    cleanup => $bool, # default is true
    minify => $bool, # compress assets
    no_autodetect => $bool, # disable preprocessor autodetection
    rebuild => $bool, # overwrite if assets exists
  };

Will register the C<compress> helper. All arguments are optional.

"cleanup" will remove any old processed files. You want to disable this if you
have other web sites that need to access an old version of the minified files.

"minify" will default to true if L<Mojolicious/mode> is "production".

"rebuild" can be set to true to always rebuild the compressed files when the
application is started. The default is to use the cached files.

=cut

sub register {
  my($self, $app, $config) = @_;
  my $minify = $config->{minify} // $app->mode eq 'production';
  my $helper = $config->{helper} || 'asset';

  $self->minify($minify);
  $self->rebuild($config->{rebuild} || 0);
  $self->preprocessors->detect unless $config->{no_autodetect};

  $self->{assets} = {};
  $self->{cleanup} //= 1;
  $self->{log} = $app->log;
  $self->{out_dir} = $app->home->rel_dir('public/packed');
  $self->{static} = $app->static;

  mkdir $self->{out_dir}; # TODO: Use mkpath instead?

  $app->helper($helper => sub {
    return $self if @_ == 1;
    return shift, $self->add(@_) if @_ > 2;
    return $self->expand(@_) unless $minify;
    return $_[0]->javascript("/packed/$self->{assets}{$_[1]}") if $_[1] =~ /\.js$/;
    return $_[0]->stylesheet("/packed/$self->{assets}{$_[1]}");
  });
}

sub _compile_css {
  my($self, $file) = @_;
  my $original = $file;

  if($file =~ s/\.(scss|less)$/.css/) {
    eval {
      my $extension = $1;
      my $in = $self->{static}->file($original)->path;
      (my $out = $in) =~ s/\.\w+$/.css/;
      my $text = slurp $in;
      $self->preprocessors->process($extension, $self, \$text, $in);
      spurt $text, $out;
      1;
    } or do {
      $self->{log}->warn("Could not convert $original: $@");
    };
  }

  $file;
}

sub _find_processed {
  my($self, $moniker) = @_;
  my($name, $ext) = $moniker =~ m!^(.+)\.(\w+)$!;

  $self->{assets}{$moniker} = "$name-not-found.$ext";

  opendir(my $DH, $self->{out_dir});
  for my $file (readdir $DH) {
    $file =~ m!^$name-\w{32}\.$ext! or next;
    $self->{assets}{$moniker} = $file;
    last;
  }
}

sub _remove_processed {
  my($self, $moniker) = @_;
  my($name, $ext) = $moniker =~ m!^(.+)\.(\w+)$!;

  opendir(my $DH, $self->{out_dir});
  for my $file (readdir $DH) {
    $file =~ m!^$name-\w{32}\.$ext! or next;
    $self->{log}->debug("Removing $self->{out_dir}/$file");
    unlink catfile($self->{out_dir}, $file) or die "Could not unlink $self->{out_dir}/$file: $!";
  }
}

sub _rename_processed {
  my($self, $moniker, $checksum) = @_;
  my($name, $ext) = $moniker =~ m!^(.+)\.(\w+)$!;
  my $source = catfile $self->{out_dir}, $moniker;
  my $destination = catfile $self->{out_dir}, "$name-$checksum.$ext";

  $self->{assets}{$moniker} = "$name-$checksum.$ext";
  return if -e $destination;
  rename $source, $destination or die "Could not rename $source to $destination: $!";
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
