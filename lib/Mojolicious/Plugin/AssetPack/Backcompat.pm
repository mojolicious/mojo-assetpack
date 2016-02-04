package Mojolicious::Plugin::AssetPack::Backcompat;
use Mojo::Base 'Mojolicious::Plugin';
use Mojo::ByteStream;
use Mojo::JSON ();
use Mojo::Util ();
use Mojolicious::Plugin::AssetPack::Preprocessors;
use Cwd ();
use File::Basename qw( basename );
use File::Path ();
use File::Spec::Functions qw( catdir catfile );
use constant DEBUG    => $ENV{MOJO_ASSETPACK_DEBUG}    || 0;
use constant NO_CACHE => $ENV{MOJO_ASSETPACK_NO_CACHE} || 0;

my $MONIKER_RE = qr{^(.+)\.(\w+)$};

has base_url => '/packed/';
has preprocessors => sub { Mojolicious::Plugin::AssetPack::Preprocessors->new };

sub add {
  my ($self, $moniker, @files) = @_;

  @files = $self->_expand_wildcards(@files);
  return $self->tap(sub { $self->{files}{$moniker} = \@files; $self }) if NO_CACHE;
  return $self->tap(sub { $self->_processed($moniker, $self->_process($moniker, @files)) }
  ) if $self->minify;
  return $self->tap(
    sub { $self->_processed($moniker, $self->_process_many($moniker, @files)) });
}

sub fetch {
  my $self  = shift;
  my $url   = Mojo::URL->new(shift);
  my $asset = $self->_handler($url->scheme || 'https')->asset_for($url, $self);
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
  my $file_re
    = $self->minify ? qr/^(.*?)-(\w{32})\.min\.(\w+)$/ : qr/^(.*?)-(\w{32})\.(\w+)$/;
  my ($PACKED, %existing);

  # default to not purging, unless in development mode
  local $args->{always} = $args->{always} // $self->_app->mode eq 'development';

  return $self unless $args->{always};
  die '$app->asset->purge() must be called AFTER $app->asset(...)'
    unless keys %{$self->{asset} || {}};
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

  if (my $paths = $config->{source_paths}) {
    $self->{source_paths}
      = [map { -d $_ ? Cwd::abs_path($_) : $app->home->rel_file($_) } @$paths];
  }

  $self->headers($config->{headers}) if $config->{headers};
  $self->minify($config->{minify} // $app->mode ne 'development');
  $self->base_url($config->{base_url}) if $config->{base_url};
  $self->_build_out_dir($app, $config);

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

sub _asset {
  my ($self, $name) = @_;
  $self->{asset}{$name} ||= Mojolicious::Plugin::AssetPack::Backcompat::Asset->new(
    path => catfile $self->out_dir,
    $name
  );
}

sub _build_out_dir {
  my ($self, $app, $config) = @_;
  my ($out_dir, $packed);

  if ($out_dir = $config->{out_dir}) {
    my $static_dir = Cwd::abs_path(catdir $out_dir, File::Spec->updir);
    push @{$app->static->paths}, $static_dir
      unless grep { $_ eq $static_dir } @{$app->static->paths};
  }
  if (!$out_dir) {
    for my $path (@{$app->static->paths}) {
      $packed = catdir $path, 'packed';
      if (-w $path) { $out_dir = Cwd::abs_path($packed); last }
      if (-r $packed) { $out_dir ||= Cwd::abs_path($packed) }
    }
  }

  $out_dir ||= $packed or die "[AssetPack] app->static->paths is not set";
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

  NO_CACHE
    and $self->_processed($moniker,
    $self->_process_many($moniker, @{$self->{files}{$moniker} || []}));

  return Mojo::ByteStream->new(qq(<!-- Asset '$moniker' is not defined\. -->))
    unless my @res = $self->get($moniker, $args);
  return $c->$tag_helper(@attrs, sub { join '', @res }) if $args->{inline};
  return Mojo::ByteStream->new(join "\n", map { $c->$tag_helper($_, @attrs) } @res);
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
    $asset
      = $self->_packed($self->minify
      ? qr{^$name-$checksum[0](\.min)?\.$ext$}
      : qr{^$name-$checksum[0]\.$ext$});
    return $asset if $asset;                  # already processed

    $file = $self->minify ? "$name-$checksum[0].min.$ext" : "$name-$checksum[0].$ext";
    $asset = $self->_asset($file);
    warn sprintf "[AssetPack] Creating %s from %s\n", $file, join ', ',
      map { $_->path } @sources
      if DEBUG;

    for my $s (@sources) {
      $topic = basename($s->path);
      my $content = $s->slurp;
      $self->preprocessors->process(_ext($s->path), $self, \$content, $s->path);
      $asset->add_chunk($content);
    }

    $self->{processed}{$moniker} = [$file];
    $self->_app->log->info(
      "AssetPack built @{[$asset->path]} for @{[$self->_app->moniker]}.");
  };

  return $asset unless $@;

  my $source_paths = join ',', @{$self->source_paths};
  my $static_paths = join ',', @{$self->_app->static->paths};
  die
    "[AssetPack/$moniker] $@ {source_paths=[$source_paths], static_paths=[$static_paths]}";
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

package Mojolicious::Plugin::AssetPack::Backcompat::Asset;

use Mojo::Base -base;
use File::Basename 'dirname';
use Fcntl qw( O_CREAT O_EXCL O_RDONLY O_RDWR );
use IO::File;

has handle => sub {
  my $self   = shift;
  my $path   = $self->path;
  my $handle = IO::File->new;

  if (-w $path) {
    $handle->open($path, O_RDWR) or die "Can't open $path (O_RDWR): $!";
  }
  elsif (!-r _ and -w dirname($path)) {
    $handle->open($path, O_CREAT | O_EXCL | O_RDWR)
      or die "Can't open $path (O_CREAT|O_EXCL|O_RDWR): $!";
  }
  else {
    $handle->open($path, O_RDONLY) or die "Can't open $path (O_RDONLY): $!";
  }

  return $handle;
};

has path => undef;

sub add_chunk {
  my $self = shift;
  defined $self->handle->syswrite($_[0]) or die "Can't write to @{[$self->path]}: $!";
  return $self;
}

sub slurp {
  my $self   = shift;
  my $handle = $self->handle;
  $handle->sysseek(0, 0);
  defined $handle->sysread(my $content, -s $handle, 0)
    or die "Can't read from @{[$self->path]}: $!";
  return $content;
}

sub spurt {
  my $self   = shift;
  my $handle = $self->handle;
  $handle->truncate(0);
  $handle->sysseek(0, 0);
  defined $handle->syswrite($_[0]) or die "Can't write to @{[$self->path]}: $!";
  return $self;
}

sub _spurt_error_message_for {
  my ($self, $ext, $err) = @_;

  $err =~ s!\r!!g;
  $err =~ s!\n+$!!;

  if ($ext eq 'js') {
    $err =~ s!'!"!g;
    $err =~ s!\n!\\n!g;
    $err =~ s!\s! !g;
    $err = "alert('$err');console.log('$err');";
  }
  else {
    $err =~ s!"!'!g;
    $err =~ s!\n!\\A!g;
    $err =~ s!\s! !g;
    $err
      = qq(html:before{background:#f00;color:#fff;font-size:14pt;position:fixed;padding:20px;z-index:9999;content:"$err";});
  }

  $self->spurt($err);
}

1;

=head1 NAME

Mojolicious::Plugin::AssetPack::Backcompat - Provides back compat functionality

=head1 METHODS

=head2 add

=head2 fetch

=head2 get

=head2 headers

=head2 out_dir

=head2 purge

=head2 register

=head2 source_paths

=head1 SEE ALSO

L<Mojolicious::Plugin::AssetPack>.

=cut
