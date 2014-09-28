package Mojolicious::Plugin::AssetPack;

=head1 NAME

Mojolicious::Plugin::AssetPack - Compress and convert css, less, sass, javascript and coffeescript files

=head1 VERSION

0.24

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

Or if you need to add the tags manually:

  % for my $asset (asset->get('app.js')) {
    %= javascript $asset
  % }

See also L</register>.

=head1 ENVIRONMENT

=head2 MOJO_ASSETPACK_NO_CACHE

If true, convert the assets each time they're expanded, instead of once at
application start (useful for development). Has no effect when L</minify> is
enabled.

=head1 DESCRIPTION

=head2 Production mode

This plugin will compress scss, less, css, javascript and coffeescript with the
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

=head2 Preprocessors

This library tries to find default preprocessors for less, scss, js, coffee
and css.

NOTE! The preprocessors require optional dependencies to function properly.
Check out L<Mojolicious::Plugin::AssetPack::Preprocessors/detect> for more
details.

You can also define your own preprocessors:

  app->asset->preprocessors->add(js => sub {
    my($assetpack, $text, $file) = @_;
    $$text = "// yikes!\n" if 5 < rand 10;
  });

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

=cut

use Mojo::Base 'Mojolicious::Plugin';
use Mojo::ByteStream 'b';
use Mojo::Util qw( md5_sum slurp spurt );
use Mojolicious::Plugin::AssetPack::Preprocessors;
use File::Basename qw( basename );
use File::Spec::Functions qw( catdir catfile );
use constant DEBUG => $ENV{MOJO_ASSETPACK_DEBUG} || 0;

our $VERSION = '0.24';
our %MISSING_ERROR = (
  default => '%s has no preprocessor. https://metacpan.org/pod/Mojolicious::Plugin::AssetPack::Preprocessors#detect',
  coffee => '%s require "coffee". http://coffeescript.org/#installation',
  jsx => '%s require "jsx". http://facebook.github.io/react',
  less => '%s require "less". http://lesscss.org/#usage',
  sass => '%s require "sass". http://sass-lang.com/install',
  scss => '%s require "sass". http://sass-lang.com/install',
);

=head1 ATTRIBUTES

=head2 base_url

  $self = $self->base_url("http://my-domain.com/static/");
  $str = $self->base_url;

This attribute can be used to control where to serve static assets from.
it defaults to "/packed". See also L</Custom domain>.

NOTE! You need to have a trailing "/" at the end of the string.

=head2 minify

Set this to true if the assets should be minified.

=head2 preprocessors

Holds a L<Mojolicious::Plugin::AssetPack::Preprocessors> object.

=head2 out_dir

Holds the path to the directory where packed files can be written. It
defaults to "mojo-assetpack" directory in L<temp|File::Spec::Functions/tmpdir>
unless a L<static directory|Mojolicious::Static/paths> is writeable.

=cut

has base_url => '/packed/';
has minify => 0;
has preprocessors => sub { Mojolicious::Plugin::AssetPack::Preprocessors->new };
has out_dir => sub { catdir File::Spec::Functions::tmpdir(), 'mojo-assetpack' };

=head2 rebuild

Deprecated.

=cut

sub rebuild {
  warn "rebuild() has no effect any more. Will soon be removed."
}

has _ua => sub {
  require Mojo::UserAgent;
  my $ua = Mojo::UserAgent->new(max_redirects => 3);
  $ua->server->app($_[0]->_app);
  return $ua;
};

has '_app';

=head1 METHODS

=head2 add

  $self->add($moniker => @rel_files);

Used to define new assets aliases. This method is called when the C<asset()>
helper is called on the app.

=cut

sub add {
  my($self, $moniker, @files) = @_;

  warn "[ASSETPACK] add $moniker => @files\n" if DEBUG;

  $self->{assets}{$moniker} = \@files;

  if($self->minify) {
    $self->process($moniker => @files);
  }
  elsif(!$ENV{MOJO_ASSETPACK_NO_CACHE}) {
    $self->{processed}{$moniker} = [$self->_process_many($moniker, @files)];
  }

  $self;
}

=head2 expand

  $bytestream = $self->expand($c, $moniker);

This method will return one tag for each asset defined by the "$moniker".

Will also run L</less>, L</sass> or L</coffee> on the files to convert them to
css or js, which the browser understands. (With L</MOJO_ASSETPACK_NO_CACHE>
enabled, this is done each time on expand; with it disabled, this is done once
when the asset is added.)

The returning bytestream will contain style or script tags.

=cut

sub expand {
  my($self, $c, $moniker) = @_;
  my @processed_files;

  warn "[ASSETPACK] expand $moniker\n" if DEBUG;

  if ($ENV{MOJO_ASSETPACK_NO_CACHE}) {
    @processed_files = $self->_process_many($moniker, @{ $self->{assets}{$moniker} });
  }
  elsif(ref $self->{processed}{$moniker} eq 'ARRAY') {
    @processed_files = @{ $self->{processed}{$moniker} };
  }
  else {
    warn "[ASSETPACK] Cannot expand $moniker\n" if DEBUG;
    return b "<!-- Cannot expand $moniker -->";
  }

  if($moniker =~ /\.js/) {
    return b join "\n", map { $c->javascript($_) } @processed_files;
  }
  else {
    return b join "\n", map { $c->stylesheet($_) } @processed_files;
  }
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

  $lookup =~ s![^\w-]!_!g;

  if (my $name = $self->_fluffy_find(qr{^$lookup\.\w+$})) {
    return catfile $self->out_dir, $name;
  }

  my $res = $self->_ua->get($url)->res;
  my $ct = $res->headers->content_type // 'text/plain';
  my $ext = Mojolicious::Types->new->detect($ct) || 'txt';
  my $path;

  $ext = $ext->[0] if ref $ext;
  $ext = Mojo::URL->new($url)->path =~ m!\.(\w+)$! ? $1 : 'txt' if !$ext or $ext eq 'bin';

  if (my $e = $res->error) {
    die "AssetPack could not download asset from '$url': $e->{message}\n";
  }

  $path = catfile $self->out_dir, "$lookup.$ext";
  spurt $res->body, $path;
  $self->{log}->info("Downloaded asset $url to $path");
  return $path;
}

=head2 get

  @files = $self->get($moniker);

Returns a list of files which the moniker point to. The list will only
contain one file if the C<$moniker> is minified.

=cut

sub get {
  my($self, $moniker) = @_;
  my $files = $self->{processed}{$moniker};

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
  my ($self, $moniker, @files) = @_;
  my ($md5_sum, $files) = $self->_read_files(@files);
  my $out_file = $moniker;
  my $processed = '';
  my (@missing, $name);

  $out_file =~ s/\.(\w+)$// or die "Moniker ($moniker) need to have an extension, like .css, .js, ...";

  if (!$ENV{MOJO_ASSETPACK_NO_CACHE} and $name = $self->_fluffy_find(qr{^$out_file(-$md5_sum)?\.\w+$})) {
    $self->{log}->debug("Using existing asset for $moniker");
    $self->{processed}{$moniker} = $self->base_url .$name;
    return $self;
  }

  $out_file .= "-$md5_sum" .($moniker =~ m!(\.\w+)$!)[0];

  for my $file (@files) {
    my $data = $files->{$file};
    if ($data->{path}) {
      warn "[ASSETPACK] process $file ($data->{path})\n" if DEBUG;
      $self->preprocessors->process($data->{ext}, $self, \$data->{body}, $data->{path});
      $processed .= $data->{body};
    }
    else {
      my $error = $MISSING_ERROR{$data->{ext}} // $MISSING_ERROR{default};
      push @missing, $data->{ext};
      $self->{log}->error(sprintf "AssetPack: $error", $file);
    }
  }

  if (@missing) {
    $self->{processed}{$moniker} = "/Mojolicious/Plugin/AssetPack/could/not/compile/$moniker";
  }
  elsif ($md5_sum eq md5_sum($processed) and $files[0] !~ /^http\s?:/) {
    warn "[ASSETPACK] Same input as output for $files[0]\n" if DEBUG;
    $self->{processed}{$moniker} = $files[0];
  }
  else {
    spurt $processed, catfile $self->out_dir, $out_file;
    $self->{log}->debug("Built asset for $moniker ($out_file)");
    $self->{processed}{$moniker} = $self->base_url .$out_file;
  }

  $self;
}

=head2 register

  plugin AssetPack => {
    base_url => $str, # default to "/packed"
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

  $self->_app($app);
  $self->minify($minify);
  $self->base_url($config->{base_url}) if $config->{base_url};
  $self->preprocessors->detect unless $config->{no_autodetect};

  $self->{assets} = {};
  $self->{processed} = {};
  $self->{log} = $app->log;
  $self->{static} = $app->static;

  warn "[ASSETPACK] Will rebuild assets on each request.\n" if DEBUG and $ENV{MOJO_ASSETPACK_NO_CACHE};

  if($config->{out_dir}) {
    $self->out_dir($config->{out_dir});
    push @{ $app->static->paths } , $config->{out_dir};
  }
  else {
    for my $path (@{ $app->static->paths }) {
      next unless -w $path;
      $self->out_dir(catdir $path, 'packed');
    }
  }

  unless(-d $self->out_dir) {
    mkdir $self->out_dir or die "AssetPack could not create out_dir '$self->{out_dir}': $!";
  }

  $app->helper($helper => sub {
    return $self if @_ == 1;
    return shift, $self->add(@_) if @_ > 2;
    return $self->expand(@_) unless $self->minify;
    return $_[0]->javascript($self->{processed}{$_[1]}) if $_[1] =~ /\.js$/;
    return $_[0]->stylesheet($self->{processed}{$_[1]});
  });
}

sub _fluffy_find {
  my ($self, $re) = @_;

  opendir (my $DH, $self->out_dir) or die "opendir @{[$self->out_dir]}: $!";
  for my $f (readdir $DH) {
    next unless $f =~ $re;
    return $f;
  }

  return;
}

sub _process_many {
  my($self, $moniker, @files) = @_;
  my $ext = $moniker =~ /\.(\w+)$/ ? $1 : 'unknown_extension';

  for my $file (@files) {
    my $moniker = basename $file;

    unless ($moniker =~ s!\.(\w+)$!.$ext!) {
      $moniker = $file;
      $moniker =~ s![^\w-]!_!g;
      $moniker .= ".$ext";
    }

    $self->process($moniker => $file);
    $file = $self->{processed}{$moniker};
  }

  return @files;
}

sub _read_files {
  my ($self, @files) = @_;
  my (@checksum, %files);

  FILE:
  for my $file (@files) {
    my $data = $files{$file} = { ext => $file =~ /\.(\w+)$/ ? $1 : 'default' };

    if ($file !~ /^https?:/ && (my $asset = $self->{static}->file($file))) {
      $data->{path} = $asset->path if $self->preprocessors->has_subscribers($data->{ext});
      $data->{body} = slurp $asset->path;
    }
    else {
      $data->{path} = $self->fetch($file);
      $data->{body} = slurp $data->{path};
    }

    push @checksum, $self->preprocessors->checksum($data->{ext}, \$data->{body}, $data->{path});
  }

  return(
    @checksum == 1 ? $checksum[0] : md5_sum(join '', @checksum),
    \%files,
  );
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
