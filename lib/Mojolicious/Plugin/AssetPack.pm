package Mojolicious::Plugin::AssetPack;

=head1 NAME

Mojolicious::Plugin::AssetPack - Compress and convert css, less, sass, javascript and coffeescript files

=head1 VERSION

0.33

=head1 SYNOPSIS

In your application:

  use Mojolicious::Lite;

  plugin 'AssetPack';

  # define assets: $moniker => @real_assets
  app->asset('app.js' => '/js/foo.js', '/js/bar.js', '/js/baz.coffee');
  app->asset('app.css' => '/css/foo.less', '/css/bar.scss', '/css/main.css');

  # you can combine with assets from web
  app->asset('ie8.js' => (
    'http://cdnjs.cloudflare.com/ajax/libs/es5-shim/2.3.0/es5-shim.js',
    'http://cdnjs.cloudflare.com/ajax/libs/es5-shim/2.3.0/es5-sham.js',
    'http://code.jquery.com/jquery-1.11.0.js',
    '/js/myapp.js',
  ));

  app->start;

In your template:

  %= asset 'app.js'
  %= asset 'app.css'

Or if you want the asset inlined in the HTML:

  %= asset 'app.css', { inline => 1 }

You can also pass on attributes to the generated HTML tag:

  %= asset 'app.css', {}, media => "print,handheld,embossed"

Or if you need to add the tags manually:

  % for my $asset (asset->get('app.js')) {
    %= javascript $asset
  % }

See also L</register>.

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack> is a L<Mojolicious> plugin which can be used
to cram multiple assets of the same type into one file. This means that if
you have a lot of CSS files (.css, .less, .sass, ...) as input, the AssetPack
can make one big CSS file as output. This is good, since it will often speed
up the rendering of your page. The output file can even be minified, meaning
you can save bandwidth and browser parsing time.

The core preprocessors that are bundled with this module can handle CSS and
JavaScript files, written in many languages.

See L<Mojolicious::Plugin::AssetPack::Preprocessors> for more details.

=head2 Production mode

This plugin will compress sass, less, css, javascript and coffeescript with the
help of external applications on startup. The result will be one file with all
the sources combined. This file is stored in L</Packed directory>.

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

You can also set the L</MOJO_ASSETPACK_NO_CACHE> environment variable to 1 to
convert your less/sass/coffee files each time their asset directive is expanded
(only works when L</minify> is disabled).

=head2 Inlined assets

AssetPack is able to insert your assets directly into your markup. This is
useful if you want to make a one-page app and want to keep the number of
requests to the server at a minimum. However, the images, fonts or any other
external asset which again is referred to require more requests to the
server. See below on how to include the asset directly in your template:

  %= asset 'app.css', { inline => 1 }

Or for manual inspection:

  % for my $data (asset->get('app.js', { inline => 1 })) {
    %== $data;
  }

=head2 Custom domain

You might want to serve the assets from a domain different from where the
main app is running. The reasons for that might be:

=over 4

=item *

No cookies send on each request. This is especially useful when you use
L<Mojolicious> sessions as they are stored in cookies and clients send
whole session with every request.

=item *

More request done in parallel. Browsers have limits for sending parallel
request to one domain. With separate domain static files can be loaded in
parallel.

=item *

Serve files directly (by absolute url) from CDN (or Amazon S3).

=back

This plugin support this if you set a custom L</base_url>.

See also L<https://developers.google.com/speed/docs/best-practices/request#ServeFromCookielessDomain>.

=head1 ENVIRONMENT

=head2 MOJO_ASSETPACK_DEBUG

Set this to get extra debug information to STDERR from AssetPack internals.

=head2 MOJO_ASSETPACK_NO_CACHE

If true, convert the assets each time they're expanded, instead of once at
application start (useful for development). Has no effect when L</minify> is
enabled.

=cut

use Mojo::Base 'Mojolicious::Plugin';
use Mojo::ByteStream 'b';
use Mojo::Util qw( md5_sum slurp spurt );
use Mojolicious::Plugin::AssetPack::Preprocessors;
use File::Basename qw( basename );
use File::Path ();
use File::Spec ();
use constant CACHE_ASSETS => $ENV{MOJO_ASSETPACK_NO_CACHE} ? 0 : 1;
use constant DEBUG => $ENV{MOJO_ASSETPACK_DEBUG} || 0;

our $VERSION = '0.33';

=head1 ATTRIBUTES

=head2 base_url

  $self = $self->base_url("http://my-domain.com/static/");
  $str = $self->base_url;

This attribute can be used to control where to serve static assets from.
it defaults to "/packed". See also L</Custom domain>.

NOTE! You need to have a trailing "/" at the end of the string.

=head2 fallback

  $self = $self->fallback($bool);

Setting this attribute to true will enable the L<asset()|/add> helper to use
bundled assets if the L</process> step fail. L<asset()|/add> will still throw
an error if there are no bundled assets available.

The default value is "1" in L<production mode|Mojolicious/mode>.

This feauture is EXPERIMENTAL. Feedback wanted.

=head2 minify

Set this to true if the assets should be minified.

=head2 preprocessors

Holds a L<Mojolicious::Plugin::AssetPack::Preprocessors> object.

=head2 out_dir

Holds the path to the directory where packed files can be written. It
defaults to "mojo-assetpack-public/packed" directory in L<temp|File::Spec/tmpdir>
unless a L<static directory|Mojolicious::Static/paths> is writeable.

=cut

has base_url      => '/packed/';
has fallback      => 0;
has minify        => 0;
has preprocessors => sub { Mojolicious::Plugin::AssetPack::Preprocessors->new };
has out_dir       => sub { shift->_build_out_dir };

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

=head2 fetch

  $path = $self->fetch($url);

This method can be used to fetch an asset and store the content to a local
file. The download will be skipped if the file already exists. The return
value is the absolute path to the downloaded file.

=cut

sub fetch {
  my ($self, $url, $destination) = @_;
  my $lookup = $url;
  my $path;

  $lookup =~ s![^\w-]!_!g;

  if (my $name = $self->_fluffy_find(qr{^$lookup\.\w+$})) {
    $path = File::Spec->catfile($self->out_dir, $name);
    $self->{log}->debug("Asset $url is downloaded: $path");
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

=head2 get

  @files = $self->get($moniker);

Returns a list of files which the moniker point to. The list will only
contain one file if the C<$moniker> is minified.

=cut

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

=head2 preprocessor

  $self = $self->preprocessor($name => \%args);

Use this method to manually register a preprocessor.

See L<Mojolicious::Plugin::AssetPack::Preprocessor::Browserify/SYNOPSIS>
for example usage.

=cut

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

=head2 process

  $self->process($moniker => @files);

This method use L<Mojolicious::Plugin::AssetPack::Preprocessors/process> to
convert and/or minify the sources pointed at by C<$moniker>.

The result file will be stored in L</Packed directory>.

=cut

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
    $self->_fallback($moniker) or die "AssetPack could not find already packed asset '$moniker' in fallback mode.";
  };

  $self;
}

=head2 register

  plugin AssetPack => {
    base_url => $str, # default to "/packed"
    minify => $bool, # compress assets
  };

Will register the C<compress> helper. All arguments are optional.

"minify" will default to true if L<Mojolicious/mode> is "production".

=cut

sub register {
  my ($self, $app, $config) = @_;
  my $helper = $config->{helper} || 'asset';

  $self->fallback($config->{fallback} // $app->mode eq 'production');
  $self->minify($config->{minify}     // $app->mode eq 'production');
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

sub _process {
  my ($self, $moniker, @files) = @_;
  my ($md5_sum, $files) = $self->_read_files(@files);
  my ($name,    $ext)   = $self->_name_ext($moniker);
  my $processed = '';
  my $path;

  $self->{processed}{$moniker} = ["$name-$md5_sum.$ext"];

  # Need to scan all directories and not just out_dir()
  if (my $file = $self->{static}->file("packed/$name-$md5_sum.$ext") and CACHE_ASSETS) {
    $self->{log}->debug("Using existing asset for $moniker: @{[$file->path]}");
    return $self;
  }

  for my $file (@files) {
    my $data = $files->{$file};
    my $err = $self->preprocessors->process($data->{ext}, $self, \$data->{body}, $data->{path});

    $processed .= $data->{body};

    if ($err) {
      $self->{log}->error($err);
      $self->{processed}{$moniker} = ["$name-$md5_sum-with-error.$ext"];
    }
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
      $data->{path} = $asset->path;
      $data->{body} = slurp $asset->path;
      $data->{ext}  = $1 if $data->{path} =~ /\.(\w+)$/;
    }
    else {
      die "AssetPack cannot find input file '$file'.";
    }

    push @checksum, $self->preprocessors->checksum($data->{ext}, \$data->{body}, $data->{path});
  }

  return (@checksum == 1 ? $checksum[0] : md5_sum(join '', @checksum), \%files,);
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
