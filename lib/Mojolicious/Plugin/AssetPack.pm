package Mojolicious::Plugin::AssetPack;

=head1 NAME

Mojolicious::Plugin::AssetPack - Compress and convert css, less, sass and javascript files

=head1 VERSION

0.10

=head1 SYNOPSIS

In your application:

  use Mojolicious::Lite;

  plugin 'AssetPack';

  # define assets: $moniker => @real_assets
  app->asset('app.js' => '/js/foo.js', '/js/bar.js');
  app->asset('app.css' => '/css/foo.less', '/css/bar.scss', '/css/main.css');

  # you can combine with assets from web
  app->asset('bundle.js' => (
    'http://cdnjs.cloudflare.com/ajax/libs/es5-shim/2.3.0/es5-shim.js',
    'http://cdnjs.cloudflare.com/ajax/libs/es5-shim/2.3.0/es5-sham.js',
    'http://code.jquery.com/jquery-1.11.0.js',
    '/js/myapp.js',
  ));

  app->start;

In your template:

  %= asset 'app.js'
  %= asset 'app.css'

Or if you need to add the tags manually:

  % for my $asset (asset->get('app.js')) {
    %= javascript $asset
  % }

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

=head2 Preprocessors

This library tries to find default preprocessors for less, scss, js and css.

NOTE! The preprocessors require optional dependencies to function properly.
Check out L<Mojolicious::Plugin::AssetPack::Preprocessors/detect> for more
details.

You can also define your own preprocessors:

  app->asset->preprocessors->add(js => sub {
    my($assetpack, $text, $file) = @_;
    $$text = "// yikes!\n" if 5 < rand 10;
  });

=cut

use Mojo::Base 'Mojolicious::Plugin';
use Mojo::ByteStream 'b';
use Mojo::Util;
use Mojolicious::Plugin::AssetPack::Preprocessors;
use File::Basename qw( basename );
use File::Spec::Functions qw( catfile );

our $VERSION = '0.10';
our %MISSING_ERROR = (
  default => '%s has no preprocessor. https://metacpan.org/pod/Mojolicious::Plugin::AssetPack::Preprocessors#detect',
  less => '%s require "less". http://lesscss.org/#usage',
  sass => '%s require "sass". http://sass-lang.com/install',
  scss => '%s require "sass". http://sass-lang.com/install',
);

=head1 ATTRIBUTES

=head2 minify

Set this to true if the assets should be minified.

=head2 preprocessors

Holds a L<Mojolicious::Plugin::AssetPack::Preprocessors> object.

=head2 out_dir

Holds the path to the firectory where packed files can be written. It
defaults to "mojo-assetpack" directory in L<temp|File::Spec::Functions/tmpdir>
unless a L<static directory|Mojolicious::Static/paths> is writeable.

=cut

has minify => 0;
has preprocessors => sub { Mojolicious::Plugin::AssetPack::Preprocessors->new };
has out_dir => sub { File::Spec::Functions::catdir(File::Spec::Functions::tmpdir(), 'mojo-assetpack') };

=head2 rebuild

Deprecated.

=cut

sub rebuild {
  warn "rebuild() has no effect any more. Will soon be removed."
}

has _ua => sub {
  require Mojo::UserAgent;
  Mojo::UserAgent->new(max_redirects => 3);
};

=head1 METHODS

=head2 add

  $self->add($moniker => @rel_files);

Used to define new assets aliases. This method is called when the C<asset()>
helper is called on the app.

=cut

sub add {
  my($self, $moniker, @files) = @_;

  $self->{assets}{$moniker} = \@files;

  if($self->minify) {
    $self->process($moniker => @files);
  }
  else {
    for my $file (@files) {
      next unless $file =~ /\.(less|s[ac]ss)$/;
      my $moniker = basename $file;
      $moniker =~ s/\.\w+$/.css/;
      $self->process($moniker => $file);
      $file = delete $self->{assets}{$moniker};
    }
    $self->{assets}{$moniker} = \@files;
  }

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

  if(!ref $files) {
    return b "<!-- Cannot expand $moniker -->";
  }
  elsif($moniker =~ /\.js/) {
    return b join "\n", map { $c->javascript($_) } @$files;
  }
  else {
    return b join "\n", map { $c->stylesheet($_) } @$files;
  }
}

=head2 get

  @files = $self->get($moniker);

Returns a list of files which the moniker point to. The list will only
contain one file if the C<$moniker> is minified.

=cut

sub get {
  my($self, $moniker) = @_;
  my $files = $self->{assets}{$moniker};

  return unless $files;
  return @$files if ref $files;
  return $files;
}

=head2 process

  $self->process($moniker => @files);

This method use L<Mojolicious::Plugin::AssetPack::Preprocessors/process> to
convert and/or minify the sources pointed at by C<$moniker>.

The result file will be stored in L</Packed directory>.

=cut

sub process {
  my($self, $moniker, @files) = @_;
  my($md5_sum, $out, $out_file, @missing);
  my $content = {};

  # @files will contain full path after this map {}
  $md5_sum = Mojo::Util::md5_sum(join '', map { $content->{$_} = $self->_slurp } @files);

  $out_file = $moniker;
  $out_file =~ s/\.(\w{1,4})$/-$md5_sum.$1/;

  if($self->{static}->file(catfile 'packed', $out_file)) {
    $self->{log}->debug("Using existing asset for $moniker");
    $self->{assets}{$moniker} = "/packed/$out_file";
    return $self;
  }

  for my $file (@files) {
    next if $file =~ /\.(\w{1,4})$/ and $self->preprocessors->has_subscribers($1);
    push @missing, $file; # will also contain files without extensions
  }

  if($self->_missing(@missing)) {
    $self->{assets}{$moniker} = "/Mojolicious/Plugin/AssetPack/could/not/compile/$moniker";
    return;
  }

  Mojo::Util::spurt(
    join('',
      map {
        /\.(\w{1,4})$/; # checked in @missing loop
        $self->preprocessors->process($1, $self, \$content->{$_}, $_);
        $content->{$_};
      } @files
    ),
    catfile($self->out_dir, $out_file)
  );

  $self->{log}->debug("Built asset for $moniker ($out_file)");
  $self->{assets}{$moniker} = "/packed/$out_file";
  return $self;
}

=head2 register

  plugin 'AssetPack', {
    minify => $bool, # compress assets
    no_autodetect => $bool, # disable preprocessor autodetection
  };

Will register the C<compress> helper. All arguments are optional.

"minify" will default to true if L<Mojolicious/mode> is "production".

=cut

sub register {
  my($self, $app, $config) = @_;
  my $minify = $config->{minify} // $app->mode eq 'production';
  my $helper = $config->{helper} || 'asset';

  $self->minify($minify);
  $self->preprocessors->detect unless $config->{no_autodetect};

  $self->{assets} = {};
  $self->{log} = $app->log;
  $self->{static} = $app->static;

  if($config->{out_dir}) {
    $self->out_dir($config->{out_dir});
    push @{ $app->static->paths } , $config->{out_dir};
  }
  else {
    for my $path (@{ $app->static->paths }) {
      next unless -w $path;
      $self->out_dir(File::Spec::Functions::catdir($path, 'packed'));
    }
  }

  unless(-d $self->out_dir) {
    mkdir $self->out_dir or die "Could not mkdir $self->{out_dir}: $!";
  }

  $app->helper($helper => sub {
    return $self if @_ == 1;
    return shift, $self->add(@_) if @_ > 2;
    return $self->expand(@_) unless $minify;
    return $_[0]->javascript($self->{assets}{$_[1]}) if $_[1] =~ /\.js$/;
    return $_[0]->stylesheet($self->{assets}{$_[1]});
  });
}

sub _missing {
  my($self, @files) = @_;

  for(@files) {
    my $ext = /\.(\w+)$/ ? $1 : 'default';
    $self->{log}->error(sprintf $MISSING_ERROR{$ext} || $MISSING_ERROR{default}, $_);
  }

  return int @files;
}

# NOTE This method is kind of evil, since it use $_
sub _slurp {
  my $self = shift;
  my $file = $_;
  my $asset;

  if(/^https?:/) {
    $asset = $file;
    $asset =~ s![^\w\.\-]!_!g;
    $asset = catfile($self->out_dir, $asset);
    $_ = $asset;

    return Mojo::Util::slurp($asset) if -s $asset;

    my $data = $self->_ua->get($file)->res->body;
    Mojo::Util::spurt($data, $asset);
    $self->{log}->info("Downloaded asset $file to $asset");
    return $data;
  }
  elsif($asset = $self->{static}->file($file)) {
    $_ = $asset->path;
    return Mojo::Util::slurp($asset->path);
  }

  die "Could not find asset for ($file)";
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

Alexander Rymasheusky

Per Edin - C<info@peredin.com>

Viktor Turskyi

=cut

1;
