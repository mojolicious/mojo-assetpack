package Mojolicious::Plugin::Assetpipe::Pipe::Sass;
use Mojo::Base 'Mojolicious::Plugin::Assetpipe::Pipe';
use Mojolicious::Plugin::Assetpipe::Util qw($CWD checksum diag load_module DEBUG);
use File::Basename 'dirname';
use Mojo::Util;

my $FORMAT_RE = qr{^s[ac]ss$};
my $IMPORT_RE = qr{( \@import \s+ (["']) (.*?) \2 \s* ; )}x;

sub _checksum {
  my ($self, $ref, $asset) = @_;
  my $ext   = $asset->format;
  my $store = $self->assetpipe->store;
  my @c     = (checksum $$ref);

SEARCH:
  while ($$ref =~ /$IMPORT_RE/gs) {
    my @rel   = split '/', $3;
    my $name  = pop @rel;
    my $mlen  = length $1;
    my $start = pos($$ref) - $mlen;

    for my $basename ("$name.$ext", "_$name.$ext", $name, "_$name") {
      my $path = File::Spec->catfile(@rel, $basename);
      $self->{checksum_for_file}{$path}++ and next;
      if (-f $path) {
        diag '@import "%s" from relative.', $path if DEBUG >= 2;
        my $next = Mojo::Util::slurp($path);
        local $CWD = dirname $path;
        push @c, $self->_checksum(\$next, $asset);
        next SEARCH;
      }
      if (my $file = $store->file(join '/', @rel, $basename)) {
        my $next = $file->slurp;
        if ($file->isa('Mojo::Asset::Memory')) {
          diag '@import "%s" from memory.', $file if DEBUG >= 2;
          pos($$ref) = $start;
          substr $$ref, $start, $mlen, $next;
          push @c, checksum $next;
          next SEARCH;
        }
        else {
          diag '@import "%s" include_paths.', $path if DEBUG >= 2;
          local $CWD = dirname $file->path;
          my $next = $file->slurp;
          push @c, $self->_checksum(\$next, $asset);
          next SEARCH;
        }
      }
    }

    diag '@import "%s" failed.', $3 if DEBUG;
  }

  return checksum join ':', @c;
}

sub _process {
  my ($self, $assets) = @_;
  my $store = $self->assetpipe->store;
  my %opts = (include_paths => ['', @{$self->assetpipe->store->paths}]);
  my $file;

  return $assets->each(
    sub {
      my ($asset, $index) = @_;
      my $attr    = $asset->TO_JSON;
      my $content = $asset->content;
      my $path    = dirname $asset->path;

      {
        local $CWD = $path if $path;
        local $self->{checksum_for_file} = {};
        $attr->{format}   = 'css';
        $attr->{checksum} = $self->_checksum(\$content, $asset);
        $attr->{minified} = $self->assetpipe->minify;
      }

      return if $asset->format !~ $FORMAT_RE;
      return $asset->content($file)->FROM_JSON($attr) if $file = $store->load($attr);
      load_module 'CSS::Sass' or die qq(Could not load "CSS::Sass": $@);
      diag 'Minify "%s" with checksum %s.', $asset->url, $attr->{checksum} if DEBUG;
      local $opts{include_paths}[0] = $path;
      local $opts{output_style}
        = $attr->{minified}
        ? CSS::Sass::SASS_STYLE_COMPACT()
        : CSS::Sass::SASS_STYLE_NESTED();
      $content = CSS::Sass::sass2scss($content) if $asset->format eq 'sass';
      my ($css, $err, $stats) = CSS::Sass::sass_compile($content, %opts);
      die qq(Could not compile "@{[$asset->url]}": $err) if $err;
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
