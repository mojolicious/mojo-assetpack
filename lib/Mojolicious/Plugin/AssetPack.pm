package Mojolicious::Plugin::AssetPack;

use Mojo::Base 'Mojolicious::Plugin';
use Mojo::ByteStream;
use Mojo::JSON ();
use Mojo::Util ();
use Mojolicious::Plugin::AssetPack::Asset;
use Mojolicious::Plugin::AssetPack::Preprocessors;
use Cwd ();
use File::Basename qw( basename );
use File::Path ();
use File::Spec::Functions qw( catdir catfile );
use constant DEBUG    => $ENV{MOJO_ASSETPACK_DEBUG}    || 0;
use constant NO_CACHE => $ENV{MOJO_ASSETPACK_NO_CACHE} || 0;

our $VERSION = '0.64';

our $MINIFY = undef;    # internal use only!
my $MONIKER_RE = qr{^(.+)\.(\w+)$};

has base_url      => '/packed/';
has minify        => 0;
has preprocessors => sub { Mojolicious::Plugin::AssetPack::Preprocessors->new };

has _ua => sub {
  require Mojo::UserAgent;
  Mojo::UserAgent->new(max_redirects => 3);
};

sub add {
  my ($self, $moniker, @files) = @_;

  @files = $self->_expand_wildcards(@files);
  return $self->tap(sub { $self->{files}{$moniker} = \@files; $self }) if NO_CACHE;
  return $self->tap(sub { $self->_processed($moniker, $self->_process($moniker, @files)) }) if $self->minify;
  return $self->tap(sub { $self->_processed($moniker, $self->_process_many($moniker, @files)) });
}

sub fetch {
  my $self  = shift;
  my $url   = Mojo::URL->new(shift);
  my $asset = $self->_handler($url->scheme)->asset_for($url, $self);
  return $asset if @_;    # internal
  return $asset->path;    # documented api
}

sub get {
  my ($self, $moniker, $args) = @_;
  my @assets = $self->_processed($moniker);

  return @assets if $args->{assets};
  return map { $_->slurp } @assets if $args->{inline};
  return map { $self->base_url . basename($_->path) } @assets;
}

sub headers {
  my ($self, $headers) = @_;

  $self->_app->hook(
    after_static => sub {
      my $c    = shift;
      my $path = $c->req->url->path->canonicalize;
      return unless $path->[1] and 0 == index "$path", $self->base_url;
      my $h = $c->res->headers;
      $h->header($_ => $headers->{$_}) for keys %$headers;
    }
  );
}

sub out_dir { shift->{out_dir} }

sub purge {
  my ($self, $args) = @_;
  my $file_re = $self->minify ? qr/^(.*?)-(\w{32})\.min\.(\w+)$/ : qr/^(.*?)-(\w{32})\.(\w+)$/;
  my ($PACKED, %existing);

  # default to not purging, unless in development mode
  local $args->{always} = $args->{always} // $self->_app->mode eq 'development';

  return $self unless $args->{always};
  die '$app->asset->purge() must be called AFTER $app->asset(...)' unless keys %{$self->{asset} || {}};
  return $self unless -w $self->out_dir and opendir $PACKED, $self->out_dir;
  $existing{$_} = 1 for grep { $_ =~ $file_re } readdir $PACKED;
  delete $existing{$_} for map { basename $_->path } values %{$self->{asset} || {}};

  for my $file (keys %existing) {
    unlink catfile $self->out_dir, $file;
    $self->_app->log->debug("AssetPack purge $file: @{[$! || 'Deleted']}");
  }

  return $self;
}

sub register {
  my ($self, $app, $config) = @_;
  my $helper = $config->{helper} || 'asset';

  if (eval { $app->$helper }) {
    return $app->log->debug("AssetPack: Helper $helper() is already registered.");
  }
  if (my $paths = $config->{source_paths}) {
    $self->{source_paths} = [map { -d $_ ? Cwd::abs_path($_) : $app->home->rel_file($_) } @$paths];
  }

  $self->{die_on_process_error} = $ENV{MOJO_ASSETPACK_DIE_ON_PROCESS_ERROR} // $app->mode ne 'development';
  $self->{map_file} = '_assetpack.map';

  $self->_ua->server->app($app);
  Scalar::Util::weaken($self->_ua->server->{app});

  $self->_ua->proxy->detect if $config->{proxy};
  $self->headers($config->{headers}) if $config->{headers};
  $self->minify($MINIFY // $config->{minify} // $app->mode ne 'development');
  $self->base_url($config->{base_url}) if $config->{base_url};
  $self->_build_out_dir($app, $config);
  $self->_load_mapping;

  $app->helper(
    $helper => sub {
      return $self if @_ == 1;
      return shift, $self->add(@_) if @_ > 2 and ref $_[2] ne 'HASH';
      return $self->_inject(@_);
    }
  );
}

sub source_paths {
  my $self = shift;
  return $self->{source_paths} || $self->_app->static->paths unless @_;
  $self->{source_paths} = shift;
  return $self;
}

sub test_app {
  my ($class, $app) = @_;
  my $n = 0;

  require Test::Mojo;

  for my $m (0, 1) {
    Test::More::diag("minify=$m") if DEBUG;
    local $MINIFY = $m;
    my $t = Test::Mojo->new($app);
    my $processed = $t->app->asset->{processed} or next;
    for my $asset (map {@$_} values %$processed) {
      $t->get_ok("/packed/$asset")->status_is(200);
      $n++;
    }
    Test::More::ok($n, "Generated $n assets for $app with minify=$m");
  }

  return $class;
}

sub _app { shift->_ua->server->app }

sub _asset {
  my ($self, $name) = @_;
  $self->{asset}{$name} ||= Mojolicious::Plugin::AssetPack::Asset->new(path => catfile $self->out_dir, $name);
}

sub _build_out_dir {
  my ($self, $app, $config) = @_;
  my $out_dir;

  if ($out_dir = $config->{out_dir}) {
    my $static_dir = Cwd::abs_path(catdir $out_dir, File::Spec->updir);
    push @{$app->static->paths}, $static_dir unless grep { $_ eq $static_dir } @{$app->static->paths};
  }
  if (!$out_dir) {
    for my $path (@{$app->static->paths}) {
      my $packed = catdir $path, 'packed';
      if (-w $path) { $out_dir = Cwd::abs_path($packed); last }
      if (-r $packed) { $out_dir ||= Cwd::abs_path($packed) }
    }
  }
  if (!$out_dir) {
    die "[AssetPack] Could not auto detect out_dir: "
      . "Neither readable, nor writeable 'packed' directory could be found in static paths, @{$app->static->paths}. Maybe you forgot to pre-pack the assets? "
      . "https://metacpan.org/pod/Mojolicious::Plugin::AssetPack::Manual::Cookbook";
  }

  File::Path::make_path($out_dir) unless -d $out_dir;
  $self->{out_dir} = $out_dir;
}

sub _expand_wildcards {
  my $self = shift;
  my (@files, %seen);

  for my $file (@_) {
    if (!-e $file and $file =~ /\*/) {
      my @rel = split '/', $file;
      my $glob = pop @rel;

      for my $path (map { catdir $_, @rel } @{$self->source_paths}) {
        my $cwd = Mojolicious::Plugin::AssetPack::Preprocessors::CWD->new($path);
        push @files, grep { !$seen{$_} } map { join '/', @rel, $_ } sort glob $glob;
      }
    }
    else {
      push @files, $file;
      $seen{$file} = 1;
    }
  }

  return @files;
}

sub _handle_process_error {
  my ($self, $moniker, $err) = @_;
  my ($name, $ext) = $moniker =~ $MONIKER_RE;
  my $app          = $self->_app;
  my $source_paths = join ',', @{$self->source_paths};
  my $static_paths = join ',', @{$app->static->paths};
  my $msg;

  $err =~ s!\s+$!!;    # remove newlines
  $msg = "$err {source_paths=[$source_paths], static_paths=[$static_paths]}";

  # use fixed mapping
  if (my @assets = $self->_processed($moniker)) {
    $app->log->debug("AssetPack falls back to predefined mapping on: $msg");
    return @assets;
  }

  $app->log->error($msg);
  die $msg if $self->{die_on_process_error};    # EXPERIMENTAL: Prevent hot reloading when assetpack fail
  return $self->_asset("$name-err.$ext")->_spurt_error_message_for($ext, $err);
}

sub _handler {
  my ($self, $moniker) = @_;
  $self->{handler}{$moniker} ||= do {
    my $class = "Mojolicious::Plugin::AssetPack::Handler::" . ucfirst $moniker;
    eval "require $class;1" or die "Could not load $class: $@\n";
    $class->new;
  };
}

sub _inject {
  my ($self, $c, $moniker, $args, @attrs) = @_;
  my $tag_helper = $moniker =~ /\.js/ ? 'javascript' : 'stylesheet';

  NO_CACHE and $self->_processed($moniker, $self->_process_many($moniker, @{$self->{files}{$moniker} || []}));

  return Mojo::ByteStream->new(qq(<!-- Asset '$moniker' is not defined\. -->))
    unless my @res = $self->get($moniker, $args);
  return $c->$tag_helper(@attrs, sub { join '', @res }) if $args->{inline};
  return Mojo::ByteStream->new(join "\n", map { $c->$tag_helper($_, @attrs) } @res);
}

sub _load_mapping {
  my $self = shift;
  my $mode = $self->minify ? 'min' : 'normal';

  $self->{mapping} = {normal => {}, min => {}, meta => {ts => time}};
  $self->{processed} = $self->{mapping}{$mode};

  eval {
    my $file = catfile $self->out_dir, $self->{map_file};
    my $mapping = Mojo::JSON::decode_json(Mojo::Util::slurp($file));
    for my $mode (keys %$mapping) {
      $self->{mapping}{$mode}{$_} ||= $mapping->{$mode}{$_} for keys %{$mapping->{$mode}};
    }
  };
}

sub _packed {
  my $sorter = ref $_[-1] eq 'CODE' ? pop : sub {@_};
  my ($self, $needle) = @_;

  for my $dir (map { catdir $_, 'packed' } @{$self->_app->static->paths}) {
    opendir my $DH, $dir or next;
    for my $file ($sorter->(map { catfile $dir, $_ } readdir $DH)) {
      my $name = basename $file;
      next unless $name =~ $needle;
      $self->_app->log->debug("Using existing asset $file") if DEBUG;
      return $self->_asset($name)->path($file);
    }
  }

  return undef;
}

sub _process {
  my ($self, $moniker, @sources) = @_;
  my $topic = $moniker;
  my ($name, $ext) = $moniker =~ $MONIKER_RE;
  my ($asset, $file, @checksum);

  eval {
    for my $s (@sources) {
      $topic = $s;
      $s     = $self->_source_for_url($s);    # rewrite @sources
      push @checksum, $self->preprocessors->checksum(_ext($topic), \$s->slurp, $s->path);
      warn sprintf "[AssetPack] Checksum $checksum[-1] from %s\n", $s->path if DEBUG;
    }

    @checksum = (Mojo::Util::md5_sum(join '', @checksum)) if @checksum > 1;
    $asset = $self->_packed($self->minify ? qr{^$name-$checksum[0](\.min)?\.$ext$} : qr{^$name-$checksum[0]\.$ext$});
    return $asset if $asset;                  # already processed

    $file = $self->minify ? "$name-$checksum[0].min.$ext" : "$name-$checksum[0].$ext";
    $asset = $self->_asset($file);
    warn sprintf "[AssetPack] Creating %s from %s\n", $file, join ', ', map { $_->path } @sources if DEBUG;

    for my $s (@sources) {
      $topic = basename($s->path);
      my $content = $s->slurp;
      $self->preprocessors->process(_ext($s->path), $self, \$content, $s->path);
      $asset->add_chunk($content);
    }

    $self->{changed}++ unless $self->{processed}{$moniker} and $self->{processed}{$moniker}[0] eq $file;
    $self->{processed}{$moniker} = [$file];
    $self->_app->log->info("AssetPack built @{[$asset->path]} for @{[$self->_app->moniker]}.");
  };

  return $asset unless $@;
  return $self->_handle_process_error($moniker, "AssetPack could not read $topic: $@") unless $file;
  return $self->_handle_process_error($moniker, "AssetPack could not generate $file ($topic): $@");
}

sub _process_many {
  my ($self, $moniker, @files) = @_;
  my $ext = _ext($moniker);

  return map {
    my $topic = $_;
    local $_ = $topic;    # do not modify input
    s![^\w-]!_!g if /^https?:/;
    s!\.\w+$!!;
    $_ = basename $_;
    $self->_process("$_.$ext" => $topic);
  } @files;
}

sub _processed {
  my ($self, $moniker, @assets) = @_;
  return map { $self->_asset($_) } @{$self->{processed}{$moniker} || []} unless @assets;
  $self->{processed}{$moniker} = [map { basename $_->path } @assets];
  Mojo::Util::spurt(Mojo::JSON::encode_json($self->{mapping}), catfile $self->out_dir, $self->{map_file})
    if $self->{changed};
  return $self;
}

sub _source_for_url {
  my ($self, $url) = @_;

  if ($self->{asset}{$url}) {
    warn "[AssetPack] Asset already loaded: $url\n" if DEBUG;
    return $self->{asset}{$url};
  }
  if (my $scheme = Mojo::URL->new($url)->scheme) {
    warn "[AssetPack] Asset from online resource: $url\n" if DEBUG;
    return $self->fetch($url, 'internal');
  }

  my @look_in = (@{$self->source_paths}, @{$self->_app->static->paths});
  my @path = split '/', $url;

  for my $file (map { catfile $_, @path } @look_in) {
    next unless $file and -r $file;
    warn "[AssetPack] Asset from disk: $url ($file)\n" if DEBUG;
    return $self->_asset("$url")->path($file);
  }

  warn "[AssetPack] Asset from @{[$self->_app->moniker]}: $url\n" if DEBUG;
  return $self->_handler('https')->asset_for($url, $self);
}

# utils
sub _ext { local $_ = basename $_[0]; /\.(\w+)$/ ? $1 : 'unknown'; }

sub _sort_by_mtime {
  map { $_->[0] } sort { $b->[1] <=> $a->[1] } map { [$_, (stat $_)[9]] } @_;
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::AssetPack - Compress and convert css, less, sass, javascript and coffeescript files

=head1 VERSION

0.64

=head1 SYNOPSIS

=head2 Application

  use Mojolicious::Lite;

  # load plugin
  plugin "AssetPack";

  # Define assets: $moniker => @real_assets
  app->asset('app.js' => '/js/foo.js', '/js/bar.js', '/js/baz.coffee');

  # Add custom response headers for assets
  app->asset->headers({"Cache-Control" => "max-age=31536000"});

  # Remove old assets
  app->asset->purge;

  # Start the application
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

  $app->plugin("AssetPack" => {minify => $bool});
  $bool = $self->minify;

Set this to true if the assets should be minified.

Default is false in "development" L<mode|Mojolicious/mode> and true otherwise.

See also L<Mojolicious::Plugin::AssetPack::Manual::Modes>.

=head2 preprocessors

  $obj = $self->preprocessors;

Holds a L<Mojolicious::Plugin::AssetPack::Preprocessors> object.

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

=head2 headers

  $app->plugin("AssetPack" => {headers => {"Cache-Control" => "max-age=31536000"}});
  $app->asset->headers({"Cache-Control" => "max-age=31536000"});

Calling this method will add a L<after_static|Mojolicious/after_static> hook which
will set additional response headers when an asset is served.

This method is EXPERIMENTAL.

=head2 out_dir

  $app->plugin("AssetPack" => {out_dir => $str});
  $str = $self->out_dir;

Returns the path to the directory where generated packed files are located.

Changing this from the default will probably lead to inconsistency. Please
report back if you are using this feature with success.

=head2 purge

  $self = $self->purge({always => $bool});

Used to purge old packed files. This is useful if you want to avoid filling up
L</out_dir> with many versions of the packed file.

C<always> default to true if in "development" L<mode|Mojolicious/mode> and
false otherwise.

This method is EXPERIMENTAL and can change or be removed at any time.

=head2 register

  plugin AssetPack => {
    base_url     => $str,     # default to "/packed"
    headers      => {"Cache-Control" => "max-age=31536000"},
    minify       => $bool,    # compress assets
    proxy        => "detect", # autodetect proxy settings
    out_dir      => "/path/to/some/directory",
    source_paths => [...],
  };

Will register the C<asset> helper. All L<arguments|/ATTRIBUTES> are optional.

=head2 source_paths

  $self = $self->source_paths($array_ref);
  $array_ref = $self->source_paths;

This method returns a list of paths to source files. The default is to return
L<Mojolicious::Static/paths> from the current application object, but you can
specify your own paths.

See also L<Mojolicious::Plugin::AssetPack::Manual::Assets/Custom source directories>
for more information.

This method is EXPERIMENTAL and can change, but will most likely not be removed.

=head2 test_app

  Mojolicious::Plugin::AssetPack->test_app("MyApp");

This method will create two L<Mojo::Test> instances of "MyApp" and create
assets with L</minify> set to 0 and 1.
L<Mojolicious::Plugin::AssetPack::Manual::Cookbook/SHIPPING> for more details.

This method is EXPERIMENTAL.

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
