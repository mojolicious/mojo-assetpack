package Mojolicious::Plugin::Assetpipe::Pipe::Sass;
use Mojo::Base 'Mojolicious::Plugin::Assetpipe::Pipe';
use Mojolicious::Plugin::Assetpipe::Util qw(checksum diag load_module DEBUG);
use File::Basename 'dirname';
use Mojo::Util;

my $FORMAT_RE = qr{^s[ac]ss$};
my $IMPORT_RE = qr{( \@import \s+ (["']) (.*?) \2 \s* ; )}x;

sub _checksum {
  my ($self, $ref, $asset, $paths) = @_;
  my $ext   = $asset->format;
  my $store = $self->assetpipe->store;
  my @c     = (checksum $$ref);

SEARCH:
  while ($$ref =~ /$IMPORT_RE/gs) {
    my @rel   = split '/', $3;
    my $name  = pop @rel;
    my $mlen  = length $1;
    my $start = pos($$ref) - $mlen;

    for my $basename ("_$name.$ext", "$name.$ext", "_$name", $name) {
      my $path = join '/', @rel, $basename;
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

sub _process {
  my ($self, $assets) = @_;
  my $store = $self->assetpipe->store;
  my %opts = (include_paths => [undef, @{$self->assetpipe->store->paths}]);
  my $file;

  return $assets->each(
    sub {
      my ($asset, $index) = @_;
      my ($attr, $content);

      return if $asset->format !~ $FORMAT_RE;
      ($attr, $content) = ($asset->TO_JSON, $asset->content);
      local $opts{include_paths}[0]
        = $asset->url =~ m!^https?://! ? $asset->url : dirname $asset->path;
      local $self->{checksum_for_file} = {};

      $attr->{format}   = 'css';
      $attr->{checksum} = $self->_checksum(\$content, $asset, $opts{include_paths});
      $attr->{minified} = $self->assetpipe->minify;

      return $asset->content($file)->FROM_JSON($attr) if $file = $store->load($attr);
      load_module 'CSS::Sass' or die qq/[Pipe::Sass] Could not load "CSS::Sass": $@/;
      diag 'Process "%s" with checksum %s.', $asset->url, $attr->{checksum} if DEBUG;
      local $opts{include_paths}[0] = dirname $asset->path;
      local $opts{output_style}
        = $attr->{minified}
        ? CSS::Sass::SASS_STYLE_COMPACT()
        : CSS::Sass::SASS_STYLE_NESTED();
      $content = CSS::Sass::sass2scss($content) if $asset->format eq 'sass';
      my ($css, $err, $stats) = CSS::Sass::sass_compile($content, %opts);
      die qq([Pipe::Sass] Could not compile "@{[$asset->url]}": $err) if $err;
      $asset->content($store->save(\$css, $attr))->FROM_JSON($attr);
    }
  );
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::Assetpipe::Pipe::Sass - Process sass and scss files

=head1 DESCRIPTION

L<Mojolicious::Plugin::Assetpipe::Pipe::Sass> will process sass and scss files.

This module require the optional module L<CSS::Sass> to minify.

=head1 SEE ALSO

L<Mojolicious::Plugin::Assetpipe>.

=cut
