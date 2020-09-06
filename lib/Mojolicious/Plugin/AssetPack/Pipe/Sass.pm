package Mojolicious::Plugin::AssetPack::Pipe::Sass;
use Mojo::Base 'Mojolicious::Plugin::AssetPack::Pipe';

use Mojolicious::Plugin::AssetPack::Util qw(checksum diag dumper load_module DEBUG);
use Mojo::File;
use Mojo::JSON qw(decode_json encode_json);
use Mojo::Util;

my $FORMAT_RE              = qr{^s[ac]ss$};
my $IMPORT_RE              = qr{ (?:^|[\n\r]+) ([^\@\r\n]*) (\@import \s+ (["']) (.*?) \3 \s* ;)}sx;
my $SOURCE_MAP_PLACEHOLDER = sprintf '__%s__', __PACKAGE__;

$SOURCE_MAP_PLACEHOLDER =~ s!::!_!g;

has functions           => sub { +{} };
has generate_source_map => sub { shift->app->mode eq 'development' ? 1 : 0 };

sub process {
  my ($self, $assets) = @_;
  my $store = $self->assetpack->store;
  my %opts  = (include_paths => [undef, @{$self->assetpack->store->paths}]);
  my $file;

  for my $name (keys %{$self->functions}) {
    my $cb = $self->functions->{$name};
    $opts{sass_functions}{$name} = sub { $self->$cb(@_); };
  }

  if ($self->generate_source_map) {
    $opts{source_map_file}      = $SOURCE_MAP_PLACEHOLDER;
    $opts{source_map_file_urls} = $self->app->mode eq 'development' ? 1 : 0;
  }

  return $assets->each(sub {
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
    $opts{include_paths}[0] = $asset->path ? $asset->path->dirname : undef;
    $opts{include_paths} = [grep {$_} @{$opts{include_paths}}];
    diag 'Process "%s" with checksum %s.', $asset->url, $attrs->{checksum} if DEBUG;

    if ($self->{has_module} //= eval { load_module 'CSS::Sass'; 1 }) {
      $opts{output_style} = _output_style($attrs->{minified});
      $content = CSS::Sass::sass2scss($content) if $asset->format eq 'sass';
      my ($css, $err, $stats) = CSS::Sass::sass_compile($content, %opts);
      if ($err) {
        die sprintf '[Pipe::Sass] Could not compile "%s" with opts=%s: %s', $asset->url, dumper(\%opts), $err;
      }
      $css = Mojo::Util::encode('UTF-8', $css);
      $self->_add_source_map_asset($asset, \$css, $stats) if $stats->{source_map_string};
      $asset->content($store->save(\$css, $attrs))->FROM_JSON($attrs);
    }
    else {
      my @args = (qw(sass -s), map { ('-I', $_) } @{$opts{include_paths}});
      push @args, '--scss'          if $asset->format eq 'scss';
      push @args, qw(-t compressed) if $attrs->{minified};
      $self->run(\@args, \$content, \my $css, undef);
      $asset->content($store->save(\$css, $attrs))->FROM_JSON($attrs);
    }
  });
}

sub _add_source_map_asset {
  my ($self, $asset, $css, $stats) = @_;
  my $data       = decode_json $stats->{source_map_string};
  my $source_map = Mojolicious::Plugin::AssetPack::Asset->new(url => sprintf('%s.css.map', $asset->name));

  # override "stdin" with real file
  $data->{file} = sprintf 'file://%s', $asset->path if $asset->path;
  $data->{sources}[0] = $data->{file};
  $source_map->content(encode_json $data);

  my $relative = join '/', '..', $source_map->checksum, $source_map->url;
  $$css =~ s!$SOURCE_MAP_PLACEHOLDER!$relative!;

  # TODO
  $self->assetpack->{by_checksum}{$source_map->checksum} = $source_map;
  $self->assetpack->{by_topic}{$source_map->url}         = Mojo::Collection->new($source_map);
}

sub _checksum {
  my ($self, $ref, $asset, $paths) = @_;
  my $ext   = $asset->format;
  my $store = $self->assetpack->store;
  my @c     = (checksum $$ref);

SEARCH:
  while ($$ref =~ /$IMPORT_RE/gs) {
    my $pre      = $1;
    my $rel_path = $4;
    my $mlen     = length $2;
    my @rel      = split '/', $rel_path;
    my $name     = pop @rel;
    my $start    = pos($$ref) - $mlen;
    my $dynamic  = $rel_path =~ m!http://local/!;
    my @basename = ("_$name", $name);

    next if $pre =~ m{^\s*//};

    # Follow sass rules for skipping,
    # ...with exception for special assetpack handling for dynamic sass include
    next if $rel_path =~ /\.css$/;
    next if $rel_path =~ m!^https?://! and !$dynamic;

    unshift @basename, "_$name.$ext", "$name.$ext" unless $name =~ /\.$ext$/;
    my $imported = $store->asset([map { join '/', @rel, $_ } @basename], $paths)
      or die qq([Pipe::Sass] Could not find "$rel_path" file in @$paths);

    if ($imported->path) {
      diag '@import "%s" (%s)', $rel_path, $imported->path if DEBUG >= 2;
      local $paths->[0] = _include_path($imported);
      push @c, $self->_checksum(\$imported->content, $imported, $paths);
    }
    else {
      diag '@import "%s" (memory)', $rel_path if DEBUG >= 2;
      pos($$ref) = $start;
      substr $$ref, $start, $mlen, $imported->content;    # replace "@import ..." with content of asset
      push @c, $imported->checksum;
    }
  }

  return checksum join ':', @c;
}

sub _include_path {
  my $asset = shift;
  return $asset->url           if $asset->url =~ m!^https?://!;
  return $asset->path->dirname if $asset->path;
  return '';
}

sub _install_sass {
  my $self = shift;
  $self->run([qw(ruby -rubygems -e), 'puts Gem.user_dir'], undef, \my $base);
  chomp $base;
  my $path = Mojo::File->new($base, qw(bin sass));
  return $path if -e $path;
  $self->app->log->warn('Installing sass... Please wait. (gem install --user-install sass)');
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

=head2 generate_source_map

  $bool = $self->generate_source_map;
  $self = $self->generate_source_map(1);

This pipe will generate source maps if true. Default is "1" if
L<Mojolicious/mode> is "development".

See also L<http://thesassway.com/intermediate/using-source-maps-with-sass> and
L<https://robots.thoughtbot.com/sass-source-maps-chrome-magic> for more
information about the usefulness.

=head1 METHODS

=head2 process

See L<Mojolicious::Plugin::AssetPack::Pipe/process>.

=head1 SEE ALSO

L<Mojolicious::Plugin::AssetPack>.

=cut
