package Mojolicious::Plugin::AssetPack::Pipe::Sass;
use Mojo::Base 'Mojolicious::Plugin::AssetPack::Pipe';
use Mojolicious::Plugin::AssetPack::Util qw(checksum diag dumper load_module DEBUG);
use File::Basename 'dirname';
use Mojo::Util;

my $FORMAT_RE = qr{^s[ac]ss$};
my $IMPORT_RE = qr{( \@import \s+ (["']) (.*?) \2 \s* ; )}x;

has functions => sub { +{} };

sub process {
  my ($self, $assets) = @_;
  my $store = $self->assetpack->store;
  my %opts = (include_paths => [undef, @{$self->assetpack->store->paths}]);
  my $file;

  for my $name (keys %{$self->functions}) {
    my $cb = $self->functions->{$name};
    $opts{sass_functions}{$name} = sub { $self->$cb(@_); };
  }

  return $assets->each(
    sub {
      my ($asset, $index) = @_;

      return if $asset->format !~ $FORMAT_RE;
      my ($attrs, $content) = ($asset->TO_JSON, $asset->content);
      local $self->{checksum_for_file} = {};
      local $opts{include_paths}[0] = _include_path($asset);
      $attrs->{minified} = $self->assetpack->minify;
      $attrs->{key}      = sprintf 'sass%s', $attrs->{minified} ? '-min' : '';
      $attrs->{format}   = 'css';
      $attrs->{checksum} = $self->_checksum(\$content, $asset, $opts{include_paths});

      return $asset->content($file)->FROM_JSON($attrs) if $file = $store->load($attrs);
      return if $asset->isa('Mojolicious::Plugin::AssetPack::Asset::Null');
      $opts{include_paths}[0] = $asset->path ? dirname $asset->path : undef;
      $opts{include_paths} = [grep {$_} @{$opts{include_paths}}];
      diag 'Process "%s" with checksum %s.', $asset->url, $attrs->{checksum} if DEBUG;

      if ($self->{has_module} //= load_module 'CSS::Sass') {
        $opts{output_style} = _output_style($attrs->{minified});
        $content = CSS::Sass::sass2scss($content) if $asset->format eq 'sass';
        my ($css, $err, $stats) = CSS::Sass::sass_compile($content, %opts);
        if ($err) {
          die sprintf '[Pipe::Sass] Could not compile "%s" with opts=%s: %s',
            $asset->url, dumper(\%opts), $err;
        }
        $css = Mojo::Util::encode('UTF-8', $css);
        $asset->content($store->save(\$css, $attrs))->FROM_JSON($attrs);
      }
      else {
        my @args = (qw(sass -s), map { ('-I', $_) } @{$opts{include_paths}});
        push @args, '--scss' if $asset->format eq 'scss';
        $self->run(\@args, \$content, \my $css, undef);
        $asset->content($store->save(\$css, $attrs))->FROM_JSON($attrs);
      }
    }
  );
}

sub _checksum {
  my ($self, $ref, $asset, $paths) = @_;
  my $ext   = $asset->format;
  my $store = $self->assetpack->store;
  my @c     = (checksum $$ref);

SEARCH:
  while ($$ref =~ /$IMPORT_RE/gs) {
    my $import   = $3;
    my @rel      = split '/', $import;
    my $name     = pop @rel;
    my $mlen     = length $1;
    my $start    = pos($$ref) - $mlen;
    my $dynamic  = $import =~ m!http://local/!;
    my @basename = ("_$name", $name);

    # Follow sass rules for skipping, with one exception
    next if $import =~ /\.css$/;
    next if $import =~ m!^https?://! and !$dynamic;

    unshift @basename, "_$name.$ext", "$name.$ext" unless $name =~ /\.$ext$/;

    for (@basename) {
      my $path = join '/', @rel, $_;
      $self->{checksum_for_file}{$path}++ and next SEARCH;
      my $imported = $store->asset($path, $paths) or next;

      if ($imported->path) {
        diag '@import "%s" (%s)', $path, $imported->path if DEBUG >= 2;
        local $paths->[0] = _include_path($imported);
        push @{$asset->{dependencies}}, $imported->path;    # hack for Reloader
        push @c, $self->_checksum(\$imported->content, $imported, $paths);
      }
      else {
        diag '@import "%s" (memory)', $path if DEBUG >= 2;
        pos($$ref) = $start;
        substr $$ref, $start, $mlen,
          $imported->content;    # replace "@import ..." with content of asset
        push @c, $imported->checksum;
      }

      next SEARCH;
    }

    local $" = ', ';
    die qq/[Pipe::Sass] Could not find "$import" file in "@{[$asset->url]}". (@$paths)/;
  }

  return checksum join ':', @c;
}

sub _include_path { $_[0]->url =~ m!^https?://! ? $_[0]->url : dirname $_[0]->path }

sub _install_sass {
  my $self = shift;
  $self->run([qw(ruby -rubygems -e), 'puts Gem.user_dir'], undef, \my $base);
  chomp $base;
  my $path = File::Spec->catfile($base, qw(bin sass));
  return $path if -e $path;
  $self->app->log->warn(
    'Installing sass... Please wait. (gem install --user-install sass)');
  $self->run([qw(gem install --user-install sass)]);
  return $path;
}

sub _output_style {
  return $_[0] ? CSS::Sass::SASS_STYLE_COMPRESSED() : CSS::Sass::SASS_STYLE_NESTED();
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::AssetPack::Pipe::Sass - Process sass and scss files

=head1 SYNOPSIS

=head2 Application

  plugin AssetPack => {pipes => [qw(Sass Css Combine)]};

  $self->pipe("Sass")->functions({
    q[image-url($arg)] => sub {
      my ($pipe, $arg) = @_;
      return sprintf "url(/assets/%s)", $_[1];
    }
  });

=head2 Sass file

The sass file below shows how to use the custom "image-url" function:

  body {
    background: #fff image-url('img.png') top left;
  }

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Pipe::Sass> will process sass and scss files.

This module require either the optional module L<CSS::Sass> or the C<sass>
program to be installed. C<sass> will be automatically installed using
L<https://rubygems.org/> unless already available.

=head1 ATTRIBUTES

=head2 functions

  $hash_ref = $self->functions;

Used to define custom SASS functions. Note that the functions will be called
with C<$self> as the first argument, followed by any arguments from the SASS
function. This invocation is EXPERIMENTAL, but will hopefully not change.

This attribute requires L<CSS::Sass> to work. It will not get passed on to
the C<sass> executable.

See L</SYNOPSIS> for example.

=head1 METHODS

=head2 process

See L<Mojolicious::Plugin::AssetPack::Pipe/process>.

=head1 SEE ALSO

L<Mojolicious::Plugin::AssetPack>.

=cut
