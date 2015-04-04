package Mojolicious::Plugin::AssetPack;

use Mojo::Base 'Mojolicious::Plugin';
use Mojo::ByteStream;
use Mojo::Util ();
use Mojolicious::Plugin::AssetPack::Asset;
use Mojolicious::Plugin::AssetPack::Preprocessors;
use Cwd            ();
use File::Basename ();
use File::Path     ();
use File::Spec     ();
use constant NO_CACHE => $ENV{MOJO_ASSETPACK_NO_CACHE} || 0;
use constant DEBUG    => $ENV{MOJO_ASSETPACK_DEBUG}    || 0;

our $VERSION = '0.47';

has base_url      => '/packed/';
has minify        => 0;
has preprocessors => sub { Mojolicious::Plugin::AssetPack::Preprocessors->new };
has out_dir       => '';

has _app => undef;
has _ua  => sub {
  require Mojo::UserAgent;
  Mojo::UserAgent->new(max_redirects => 3);
};

sub add {
  my ($self, $moniker, @files) = @_;

  return $self->tap(sub { $self->{files}{$moniker} = \@files }) if NO_CACHE;
  return $self->tap(sub { $self->_assets($moniker => $self->_process($moniker, @files)) }) if $self->minify;
  return $self->tap(sub { $self->_assets($moniker => $self->_process_many($moniker, @files)) });
}

sub fetch {
  my $self = shift;
  $self->_fetch(@_, $self->out_dir)->url;
}

sub get {
  my ($self, $moniker, $args) = @_;
  my $assets = $self->_assets($moniker);

  die "Asset '$moniker' is not defined." unless @$assets;
  return @$assets if $args->{assets};
  return map { $_->slurp } @$assets if $args->{inline};
  return map { $self->base_url . $_->basename } @$assets;
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

sub register {
  my ($self, $app, $config) = @_;
  my $helper = $config->{helper} || 'asset';

  if (eval { $app->$helper }) {
    return $app->log->debug("AssetPack: Helper $helper() is already registered.");
  }

  $self->_app($app);
  $self->_ua->server->app($app);
  $self->minify($config->{minify} // $app->mode ne 'development');
  $self->out_dir($self->_build_out_dir($config, $app));
  $self->base_url($config->{base_url}) if $config->{base_url};

  $self->{assets}    = {};
  $self->{processed} = {};

  if (NO_CACHE) {
    $app->log->info('AssetPack Will rebuild assets on each request in memory');
    $self->out_dir('');
    $self->_assets_from_memory($app);
  }
  elsif (!$self->out_dir) {
    $app->log->warn('AssetPack will store assets in memory');
    $self->_assets_from_memory($app);
  }

  $app->helper(
    $helper => sub {
      return $self if @_ == 1;
      return shift, $self->add(@_) if @_ > 2 and ref $_[2] ne 'HASH';
      return $self->_inject(@_);
    }
  );
}

sub _asset {
  my ($self, $name) = @_;
  $self->{asset}{$name} ||= Mojolicious::Plugin::AssetPack::Asset->new(url => $name);
}

sub _assets {
  my ($self, $moniker, @assets) = @_;
  $self->{assets}{$moniker} = \@assets if @assets;
  $self->{assets}{$moniker} || [];
}

sub _assets_from_memory {
  my ($self, $app) = @_;

  $app->hook(
    before_routes => sub {
      my $c    = shift;
      my $path = $c->req->url->path;

      return if $c->res->code;
      return unless $path->[1] and 0 == index "$path", $self->base_url;
      return unless my $asset = $c->asset->_asset($path->[1]);
      return $c->reply->asset($asset);
    }
  );
}

sub _build_out_dir {
  my ($self, $config, $app) = @_;
  my $out_dir = $config->{out_dir};

  if ($out_dir) {
    my $static_dir = Cwd::abs_path(File::Spec->catdir($out_dir, File::Spec->updir));
    push @{$app->static->paths}, $static_dir unless grep { $_ eq $static_dir } @{$app->static->paths};
  }
  elsif (!defined $out_dir) {
    for my $path (@{$app->static->paths}) {
      next unless -w $path;
      $out_dir = File::Spec->catdir($path, 'packed');
      last;
    }
  }

  File::Path::make_path($out_dir) if $out_dir and !-d $out_dir;
  return $out_dir // '';
}

sub _fetch {
  my ($self, $url, $save) = @_;
  my $lookup = _name($url);
  my $asset;

  if ($asset = $self->_find('packed', qr{^$lookup\.\w+$})) {
    $self->_app->log->debug("Asset $url is already downloaded") if DEBUG;
    return $asset;
  }

  my $res = $self->_ua->get($url)->res;
  my $ct  = $res->headers->content_type // 'text/plain';
  my $ext = Mojolicious::Types->new->detect($ct) || 'txt';

  if (my $e = $res->error) {
    die "Asset $url could not be fetched: $e->{message}";
  }

  $ext = $ext->[0] if ref $ext;
  $ext = Mojo::URL->new($url)->path =~ m!\.(\w+)$! ? $1 : 'txt' if !$ext or $ext eq 'bin';
  $self->_app->log->info("Asset $url was fetched");
  $asset = $self->_asset("$lookup.$ext")->url($url)->add_chunk($res->body);
  $asset->in_memory(0)->url(File::Spec->catfile($self->out_dir, "$lookup.$ext"))->save if $save;
  $asset;
}

sub _find {
  my $needle = pop;
  my $self   = shift;
  my @path   = @_;

  for my $path (map { File::Spec->catdir($_, @path) } @{$self->_app->static->paths}) {
    opendir my $DH, $path or next;
    for (readdir $DH) {
      /$needle/ and return $self->_asset($_)->url(Cwd::abs_path(File::Spec->catfile($path, $_)))->in_memory(0);
    }
  }

  return undef;
}

sub _inject {
  my ($self, $c, $moniker, $args, @attrs) = @_;
  my $tag_helper = $moniker =~ /\.js/ ? 'javascript' : 'stylesheet';

  if (NO_CACHE) {
    $self->_assets($moniker => $self->_process_many($moniker, @{$self->{files}{$moniker} || []}));
  }

  eval {
    if ($args->{inline}) {
      return $c->$tag_helper(@attrs, sub { join "\n", $self->get($moniker, $args) });
    }
    else {
      return Mojo::ByteStream->new(join "\n", map { $c->$tag_helper($_, @attrs) } $self->get($moniker, $args));
    }
    1;
  } or do {
    $self->_app->log->error($@);
    return Mojo::ByteStream->new(qq(<!-- Asset '$moniker' is not defined\. -->));
  };
}

sub _make_error_asset {
  my ($self, $moniker, $file, $err) = @_;

  $err =~ s!\r!!g;
  $err =~ s!\n+$!!;
  $err = "$file: $err";

  if ($moniker =~ /\.js$/) {
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
  my ($self, $moniker, @sources) = @_;
  my ($name, $ext) = (_name($moniker), _ext($moniker));
  my ($asset, $file, $re, @checksum);

  @sources = map {
    my $asset = $self->_find(split '/', $_) || (/^https?:/ ? $self->_fetch($_, $self->out_dir) : $self->_fetch($_, ''));
    push @checksum, $self->preprocessors->checksum(_ext($_), \$asset->slurp, $asset->url);
    $asset;
  } @sources;

  @checksum = (Mojo::Util::md5_sum(join '', @checksum)) if @checksum > 1;
  $file = $self->minify ? "$name-$checksum[0].min.$ext"          : "$name-$checksum[0].$ext";
  $re   = $self->minify ? qr{^$name-$checksum[0](\.min)?\.$ext$} : qr{^$name-$checksum[0]\.$ext$};

  if ($asset = $self->_find('packed', $re)) {
    $self->_app->log->debug("Using existing asset for $moniker") if DEBUG;
    return $asset;
  }

  $asset = $self->_asset($file)->url(File::Spec->catfile($self->out_dir, $file))->in_memory(1);

  for my $source (@sources) {
    eval {
      my $content = $source->slurp;
      $self->preprocessors->process(_ext($source->url), $self, \$content, $source->url);
      $asset->add_chunk($content);
      1;
    } or do {
      $asset->url(File::Spec->catfile($self->out_dir, "$name-$checksum[0].err.$ext"));
      $asset->add_chunk($self->_make_error_asset($moniker, $source->basename, $@));
      last;
    };
  }

  $asset->in_memory($self->out_dir ? 0 : 1)->save;
  $self->_app->log->info("Built asset for $moniker");
  $asset;
}

sub _process_many {
  my ($self, $moniker, @files) = @_;
  my $ext = _ext($moniker);
  map { my $name = _name($_); $self->_process("$name.$ext" => $_) } @files;
}

# utils
sub _ext { local $_ = File::Basename::basename($_[0]); /\.(\w+)$/ ? $1 : 'unknown'; }

sub _name {
  local $_ = $_[0];
  return do { s![^\w-]!_!g; $_ } if /^https?:/;
  $_ = File::Basename::basename($_);
  /^(.*)\./ ? $1 : $_;
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::AssetPack - Compress and convert css, less, sass, javascript and coffeescript files

=head1 VERSION

0.47

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

  $app->plugin("AssetPack" => {base_url => "/packed/"});
  $str = $self->base_url;

This attribute can be used to control where to serve static assets from.

Defaults value is "/packed/".

See L<Mojolicious::Plugin::AssetPack::Manual::CustomDomain> for more details.

NOTE! You need to have a trailing "/" at the end of the string.

=head2 minify

  $bool = $self->minify;
  $app->plugin("AssetPack" => {minify => $bool});

Set this to true if the assets should be minified.

Default is false in "development" L<mode|Mojolicious/mode> and true otherwise.

See also L<Mojolicious::Plugin::AssetPack::Manual::Modes>.

=head2 preprocessors

  $obj = $self->preprocessors;

Holds a L<Mojolicious::Plugin::AssetPack::Preprocessors> object.

=head2 out_dir

  $str = $self->out_dir;
  $app->plugin("AssetPack" => {out_dir => $str});

Holds the path to the directory where packed files can be written.

Defaults to empty string if no directory can be found, which again results in
keeping all packed files in memory.

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

=head2 register

  plugin AssetPack => {
    base_url => $str,  # default to "/packed"
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
