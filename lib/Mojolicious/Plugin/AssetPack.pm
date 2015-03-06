package Mojolicious::Plugin::AssetPack;

use Mojo::Base 'Mojolicious::Plugin';
use Mojo::ByteStream 'b';
use Mojo::Util qw( md5_sum slurp spurt );
use Mojolicious::Plugin::AssetPack::Preprocessors;
use File::Basename qw( basename );
use File::Path ();
use File::Spec ();
use constant CACHE_ASSETS => $ENV{MOJO_ASSETPACK_NO_CACHE} ? 0 : 1;
use constant DEBUG => $ENV{MOJO_ASSETPACK_DEBUG} || 0;

our $VERSION = '0.39';

has base_url      => '/packed/';
has fallback      => 0;
has minify        => 0;
has preprocessors => sub { Mojolicious::Plugin::AssetPack::Preprocessors->new };
has out_dir       => sub { shift->_build_out_dir };

has _ua => sub {
  require Mojo::UserAgent;
  Mojo::UserAgent->new(max_redirects => 3);
};

sub add {
  my ($self, $moniker, @files) = @_;

  $self->{assets}{$moniker} = \@files;

  if ($self->minify) {
    $self->process($moniker => @files);
  }
  elsif (CACHE_ASSETS) {
    $self->_process_many($moniker);
  }

  $self;
}

sub fetch {
  my ($self, $url, $destination) = @_;
  my $lookup = $url;
  my $path;

  $lookup =~ s![^\w-]!_!g;

  if (my $name = $self->_fluffy_find(qr{^$lookup\.\w+$})) {
    $path = File::Spec->catfile($self->out_dir, $name);
    $self->{log}->debug("Asset $url is downloaded: $path") if DEBUG;
    return $path;
  }

  my $res = $self->_ua->get($url)->res;
  my $ct  = $res->headers->content_type // 'text/plain';
  my $ext = Mojolicious::Types->new->detect($ct) || 'txt';

  $ext = $ext->[0] if ref $ext;
  $ext = Mojo::URL->new($url)->path =~ m!\.(\w+)$! ? $1 : 'txt' if !$ext or $ext eq 'bin';

  if (my $e = $res->error) {
    die "AssetPack could not download asset from '$url': $e->{message}";
  }

  $path = File::Spec->catfile($self->out_dir, "$lookup.$ext");
  spurt $res->body, $path;
  $self->{log}->info("Downloaded asset $url: $path");
  return $path;
}

sub get {
  my ($self, $moniker, $args) = @_;
  my $files = $self->{processed}{$moniker} || [];

  if ($args->{inline}) {
    return map { $self->{static}->file("packed/$_")->slurp } @$files;
  }
  else {
    return map { $self->base_url . $_ } @$files;
  }
}

sub preprocessor {
  my ($self, $name, $args) = @_;
  my $class = $name =~ /::/ ? $name : "Mojolicious::Plugin::AssetPack::Preprocessor::$name";
  my $preprocessor;

  $args->{extensions} or die "Usage: \$self->preprocessor(\$name => {extensions => [...]})";
  eval "require $class;1" or die "Could not load $class: $@\n";
  $preprocessor = $class->new($args);

  for my $ext (@{$args->{extensions}}) {
    warn "[ASSETPACK] Adding $class preprocessor.\n" if DEBUG;
    $self->preprocessors->on($ext => $preprocessor);
  }

  return $self;
}

sub process {
  my ($self, $moniker, @files) = @_;

  eval {
    $self->_process($moniker, @files);
    $self->_fallback($moniker) if grep {/-with-error/} @{$self->{processed}{$moniker}} and $self->fallback;
    1;
  } or do {
    my $e = $@;
    die $e unless $self->fallback;
    $e =~ s/ at \S+.*//s;
    $self->{log}->debug("AssetPack failed, but will try fallback mode. ($e)\n");
    $self->_fallback($moniker) or die "AssetPack could not find already packed asset '$moniker' in fallback mode. ($e)";
  };

  $self;
}

sub register {
  my ($self, $app, $config) = @_;
  my $helper = $config->{helper} || 'asset';

  $self->{mode} = $app->mode;
  $self->fallback($config->{fallback} // $app->mode ne 'development');
  $self->minify($config->{minify}     // $app->mode ne 'development');
  $self->base_url($config->{base_url}) if $config->{base_url};

  $self->{assets}    = {};
  $self->{processed} = {};
  $self->{log}       = $app->log;
  $self->{static}    = $app->static;

  $app->log->info('AssetPack Will rebuild assets on each request') unless CACHE_ASSETS;

  if ($config->{out_dir}) {
    $self->out_dir($config->{out_dir});
  }
  else {
    for my $path (@{$app->static->paths}) {
      next unless -w $path;
      $self->out_dir(File::Spec->catdir($path, 'packed'));
      last;
    }
  }

  unless ($self->{out_dir}) {
    push @{$app->static->paths}, File::Spec->catdir($self->out_dir, File::Spec->updir);
  }
  unless (-d $self->out_dir) {
    File::Path::make_path($self->out_dir) or die "AssetPack could not create out_dir '$self->{out_dir}': $!";
  }

  $app->helper(
    $helper => sub {
      return $self if @_ == 1;
      return shift, $self->add(@_) if @_ > 2 and ref $_[2] ne 'HASH';
      return $self->_inject(@_);
    }
  );
}

sub _build_out_dir {
  File::Spec->catdir(File::Spec->tmpdir, 'mojo-assetpack-public', 'packed');
}

sub _fallback {
  my ($self, $moniker) = @_;
  my ($name, $ext)     = $self->_name_ext($moniker);
  my $file = $self->_fluffy_find(qr/^$name-\w{32}.$ext$/) or return;

  $self->{log}->debug("Using fallback asset for $moniker: $file");
  $self->{processed}{$moniker} = [$file];
}

sub _fluffy_find {
  my ($self, $re) = @_;

  opendir(my $DH, $self->out_dir) or die "opendir @{[$self->out_dir]}: $!";
  for my $f (readdir $DH) {
    next unless $f =~ $re;
    return $f;
  }

  return;
}

sub _inject {
  my ($self, $c, $moniker, $args, @attrs) = @_;
  my $tag_helper = $moniker =~ /\.js/ ? 'javascript' : 'stylesheet';

  $self->_process_many($moniker) unless CACHE_ASSETS;
  my $processed = $self->{processed}{$moniker} || [];

  if (!@$processed) {
    return b "<!-- Asset '$moniker' is not defined. -->";
  }
  elsif ($args->{inline}) {
    return $c->$tag_helper(
      @attrs,
      sub {
        join "\n", map { $self->{static}->file("packed/$_")->slurp } @$processed;
      }
    );
  }
  else {
    return b join "\n", map { $c->$tag_helper($self->base_url . $_, @attrs) } @$processed;
  }
}

sub _name_ext {
  $_[1] =~ /^(.*)\.(\w+)$/;
  return ($1, $2) if $2;
  die "Moniker ($_[1]) need to have an extension, like .css, .js, ...";
}

sub _make_error_asset {
  my ($self, $data, $err) = @_;
  my $file = $self->{mode} eq 'development' ? $data->{path} : $data->{moniker};

  $err =~ s!\r!!g;
  $err =~ s!\n+$!!;
  $err = "$file: $err";

  if ($data->{moniker} =~ /\.js$/) {
    $err =~ s!'!"!g;
    $err =~ s!\n!\\n!g;
    $err =~ s!\s! !g;
    return "alert('$err');console.log('$err');";
  }
  else {
    $err =~ s!"!'!g;
    $err =~ s!\n!\\A!g;
    $err =~ s!\s! !g;
    return
      qq(html:before{background:#f00;color:#fff;font-size:14pt;position:absolute;padding:20px;z-index:9999;content:"$err";});
  }
}

sub _process {
  my ($self, $moniker, @files) = @_;
  my ($md5_sum, $files) = $self->_read_files(@files);
  my ($name,    $ext)   = $self->_name_ext($moniker);
  my $processed = '';
  my $path;

  $self->{processed}{$moniker} = ["$name-$md5_sum.$ext"];

  # Need to scan all directories and not just out_dir()
  if (my $file = $self->{static}->file("packed/$name-$md5_sum.$ext") and CACHE_ASSETS) {
    $self->{log}->debug("Using existing asset for $moniker: @{[$file->path]}") if DEBUG;
    return $self;
  }

  for my $file (@files) {
    my $data = $files->{$file};

    eval {
      $self->preprocessors->process($data->{ext}, $self, \$data->{body}, $data->{path});
      $processed .= $data->{body};
      1;
    } or do {
      my $e = $@;
      $self->{log}->error($e);
      local $data->{moniker} = $moniker;
      $processed .= $self->_make_error_asset($data, $e);
      $self->{processed}{$moniker} = ["$name-$md5_sum-with-error.$ext"];
    };
  }

  $path = File::Spec->catfile($self->out_dir, $self->{processed}{$moniker}[0]);
  spurt $processed => $path;
  $self->{log}->info("Built asset for $moniker: $path");
}

sub _process_many {
  my ($self, $moniker) = @_;
  my @files = @{$self->{assets}{$moniker} || []};
  my ($name, $ext) = $self->_name_ext($moniker);

  for my $file (@files) {
    my $moniker = basename $file;

    unless ($moniker =~ s!\.(\w+)$!.$ext!) {
      $moniker = $file;
      $moniker =~ s![^\w-]!_!g;
      $moniker .= ".$ext";
    }

    $self->process($moniker => $file);
    $file = $self->{processed}{$moniker}[0];
  }

  $self->{processed}{$moniker} = \@files;
}

sub _read_files {
  my ($self, @files) = @_;
  my (@checksum, %files);

FILE:
  for my $file (@files) {
    my $data = $files{$file} = {ext => 'unknown_extension'};

    if ($file =~ /^https?:/) {
      $data->{path} = $self->fetch($file);
      $data->{body} = slurp $data->{path};
      $data->{ext}  = $1 if $data->{path} =~ /\.(\w+)$/;
    }
    elsif (my $asset = $self->{static}->file($file)) {
      $data->{path} = $asset->can('path') ? $asset->path : $file;
      $data->{body} = $asset->slurp;
      $data->{ext}  = $1 if $data->{path} =~ /\.(\w+)$/;
    }
    else {
      die "AssetPack cannot find input file '$file'.";
    }

    push @checksum, $self->preprocessors->checksum($data->{ext}, \$data->{body}, $data->{path});
  }

  return (@checksum == 1 ? $checksum[0] : md5_sum(join '', @checksum), \%files,);
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::AssetPack - Compress and convert css, less, sass, javascript and coffeescript files

=head1 VERSION

0.39

=head1 SYNOPSIS

=head2 Application

  use Mojolicious::Lite;

  # load plugin
  plugin "AssetPack";

  # define assets: $moniker => @real_assets
  app->asset('app.js' => '/js/foo.js', '/js/bar.js', '/js/baz.coffee');
  app->start;

See also L<Mojolicious::Plugin::AssetPack::Manual::Assets> for more
details on how to define assets.

=head2 Template

  %= asset 'app.js'
  %= asset 'app.css'

See also L<Mojolicious::Plugin::AssetPack::Manual::Include> for more
details on how to include assets.

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack> is a L<Mojolicious> plugin which can be used
to cram multiple assets of the same type into one file. This means that if
you have a lot of CSS files (.css, .less, .sass, ...) as input, the AssetPack
can make one big CSS file as output. This is good, since it will often speed
up the rendering of your page. The output file can even be minified, meaning
you can save bandwidth and browser parsing time.

The core preprocessors that are bundled with this module can handle CSS and
JavaScript files, written in many languages.

=head1 MANUALS

The documentation is split up in different manuals, for more in-depth
information:

=over 4

=item *

See L<Mojolicious::Plugin::AssetPack::Manual::Assets> for how to define
assets in your application.

=item *

See L<Mojolicious::Plugin::AssetPack::Manual::Include> for how to include
the assets in the template.

=item *

See L<Mojolicious::Plugin::AssetPack::Manual::Modes> for how AssetPack behaves
in different modes.

=item *

See L<Mojolicious::Plugin::AssetPack::Manual::CustomDomain> for how to
serve your assets from a custom host.

=item * 

See L<Mojolicious::Plugin::AssetPack::Preprocessors> for details on the
different (official) preprocessors.

=back

=head1 ENVIRONMENT

=head2 MOJO_ASSETPACK_DEBUG

Set this to get extra debug information to STDERR from AssetPack internals.

=head2 MOJO_ASSETPACK_NO_CACHE

If true, convert the assets each time they're expanded, instead of once at
application start (useful for development).

This attribute has no effect if L</minify> is true.

=head1 HELPERS

=head2 asset

This plugin defined the helper C<asset()>. This helper can be called in
different ways:

=over 4

=item * $self = $c->asset;

This will return the plugin instance, that you can call methods on.

=item * $c->asset($moniker => @real_files);

See L</add>.

=item * $bytestream = $c->asset($moniker, \%args, @attr);

Used to include an asset in a template.

=back

=head1 ATTRIBUTES

=head2 base_url

  $str = $self->base_url;

This attribute can be used to control where to serve static assets from.

Defaults value is "/packed".

See L<Mojolicious::Plugin::AssetPack::Manual::CustomDomain> for more details.

NOTE! You need to have a trailing "/" at the end of the string.

=head2 fallback

  $bool = $self->fallback;

Used to read "old" assets if unable to generate new.

Default is false in "development" L<mode|Mojolicious/mode> and true otherwise.

See L<Mojolicious::Plugin::AssetPack::Manual::Modes/Fallback>.

=head2 minify

  $bool = $self->minify;

Set this to true if the assets should be minified.

Default is false in "development" L<mode|Mojolicious/mode> and true otherwise.

=head2 preprocessors

  $obj = $self->preprocessors;

Holds a L<Mojolicious::Plugin::AssetPack::Preprocessors> object.

=head2 out_dir

  $str = $self->out_dir;

Holds the path to the directory where packed files can be written. It
defaults to "mojo-assetpack-public/packed" directory in L<temp|File::Spec/tmpdir>
unless a L<static|Mojolicious::Static/paths> directory is writeable.

=head1 METHODS

=head2 add

  $self->add($moniker => @real_files);

Used to define assets.

See L<Mojolicious::Plugin::AssetPack::Manual::Assets> for mode details.

=head2 fetch

  $path = $self->fetch($url);

This method can be used to fetch an asset and store the content to a local
file. The download will be skipped if the file already exists. The return
value is the absolute path to the downloaded file.

=head2 get

  @files = $self->get($moniker);

Returns a list of files which the moniker point to. The list will only
contain one file if L</minify> is true.

See L<Mojolicious::Plugin::AssetPack::Manual::Include/Full control> for mode
details.

=head2 preprocessor

  $self = $self->preprocessor($name => \%args);

Use this method to manually register a preprocessor.

See L<Mojolicious::Plugin::AssetPack::Preprocessor::Browserify/SYNOPSIS>
for example usage.

=head2 process

This method will be deprecated. Use L</add> instead.

=head2 register

  plugin AssetPack => {
    base_url => $str,  # default to "/packed"
    fallback => $bool, # fallback to old assets
    minify   => $bool, # compress assets
    out_dir  => "/path/to/some/directory",
  };

Will register the C<compress> helper. All L<arguments|/ATTRIBUTES> are optional.

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
