package Mojolicious::Plugin::Assetpipe::Pipe::Sass;
use Mojo::Base 'Mojolicious::Plugin::Assetpipe::Pipe';
use Mojolicious::Plugin::Assetpipe::Util qw(binpath checksum diag load_module run DEBUG);
use File::Basename 'dirname';
use Mojo::Util;

my $FORMAT_RE = qr{^s[ac]ss$};
my $IMPORT_RE = qr{( \@import \s+ (["']) (.*?) \2 \s* ; )}x;

has _exe => sub { [shift->_make_sure_sass_is_installed] };

sub _checksum {
  my ($self, $ref, $asset, $paths) = @_;
  my $ext   = $asset->format;
  my $store = $self->assetpipe->store;
  my @c     = (checksum $$ref);

SEARCH:
  while ($$ref =~ /$IMPORT_RE/gs) {
    my @rel      = split '/', $3;
    my $name     = pop @rel;
    my $mlen     = length $1;
    my $start    = pos($$ref) - $mlen;
    my @basename = ("_$name", $name);

    unshift @basename, "_$name.$ext", "$name.$ext" unless $name =~ /\.$ext$/;

    for (@basename) {
      my $path = join '/', @rel, $_;
      $self->{checksum_for_file}{$path}++ and next;
      my $file = $store->file($path, $paths) or next;
      my $next = $file->slurp;

      if ($file->isa('Mojo::Asset::Memory')) {
        diag '@import "%s" (memory)', $path if DEBUG >= 2;
        pos($$ref) = $start;
        substr $$ref, $start, $mlen, $next;  # replace "@import ..." with content of asset
        push @c, checksum $next;
      }
      else {
        diag '@import "%s" (%s)', $path, $file->path if DEBUG >= 2;
        local $paths->[0] = dirname $file->path;
        push @c, $self->_checksum(\$next, $asset, $paths);
      }

      next SEARCH;
    }

    die qq/[Pipe::Sass] \@import "$3" failed. (@{[$asset->url]})/;
  }

  return checksum join ':', @c;
}

sub _make_sure_sass_is_installed {
  my ($self, $path) = @_;
  my $exe = $ENV{MOJO_ASSETPIPE_SASS_BIN} // binpath 'sass';
  return $exe if $exe;

  my $base = qx{ruby -rubygems -e 'puts Gem.user_dir'} || '';
  chomp $base;
  $exe = File::Spec->catfile($base, qw(bin sass));
  return $exe if -e $exe;

  $self->app->log->warn(
    'Installing sass... Please wait. (gem install --user-install sass)');
  run [qw(gem install --user-install sass)];
  return $exe;
}

sub _output_style {
  return $_[0] ? CSS::Sass::SASS_STYLE_COMPACT() : CSS::Sass::SASS_STYLE_NESTED();
}

sub _process {
  my ($self, $assets) = @_;
  my $store = $self->assetpipe->store;
  my %opts = (include_paths => [undef, @{$self->assetpipe->store->paths}]);
  my $file;

  return $assets->each(
    sub {
      my ($asset, $index) = @_;
      my ($attrs, $content);

      return if $asset->format !~ $FORMAT_RE;
      ($attrs, $content) = ($asset->TO_JSON, $asset->content);
      local $self->{checksum_for_file} = {};
      local $opts{include_paths}[0]
        = $asset->url =~ m!^https?://! ? $asset->url : dirname $asset->path;

      $attrs->{minified} = $self->assetpipe->minify;
      $attrs->{key}      = sprintf 'sass%s', $attrs->{minified} ? ':min' : '';
      $attrs->{format}   = 'css';
      $attrs->{checksum} = $self->_checksum(\$content, $asset, $opts{include_paths});

      return $asset->content($file)->FROM_JSON($attrs) if $file = $store->load($attrs);
      $opts{include_paths}[0] = dirname $asset->path;
      diag 'Process "%s" with checksum %s.', $asset->url, $attrs->{checksum} if DEBUG;

      if ($self->{has_module} //= !$self->{_exe} && load_module 'CSS::Sass') {
        $opts{output_style} = _output_style($attrs->{minified});
        $content = CSS::Sass::sass2scss($content) if $asset->format eq 'sass';
        my ($css, $err, $stats) = CSS::Sass::sass_compile($content, %opts);
        die qq([Pipe::Sass] Could not compile "$attrs->{url}": $err) if $err;
        $asset->content($store->save(\$css, $attrs))->FROM_JSON($attrs);
      }
      else {
        my @args = (@{$self->_exe}, '-s', map { ('-I', $_) } @{$opts{include_paths}});
        push @args, '--scss' if $asset->format eq 'scss';
        run \@args, \$content, \my $css, undef;
        $asset->content($store->save(\$css, $attrs))->FROM_JSON($attrs);
      }
    }
  );
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::Assetpipe::Pipe::Sass - Process sass and scss files

=head1 DESCRIPTION

L<Mojolicious::Plugin::Assetpipe::Pipe::Sass> will process sass and scss files.

This module require either the optional module L<CSS::Sass> to minify or
the C<sass> executable to be installed. C<sass> will be automatically installed
using L<https://rubygems.org/> unless already installed.

=head1 SEE ALSO

L<Mojolicious::Plugin::Assetpipe>.

=cut
