package Mojolicious::Plugin::AssetPack::Handler::Sprites;
use Mojo::Base -base;
use File::Basename 'basename';
use constant DEBUG => $ENV{MOJO_ASSETPACK_DEBUG} || 0;

sub asset_for {
  my ($self, $url, $assetpack) = @_;
  my $name  = basename $url->path;
  my $tiled = $self->_imager(xsize => 1000, ysize => 10000, channels => 4);
  my $css   = '';
  my @size  = (0, 0);
  my ($checksum, $directory);

  for my $static (@{$assetpack->_app->static->paths}) {
    $directory = File::Spec->catdir($static, $url->path);
    last if -d $directory;
  }

  die "Could not find directory for $url" unless $directory;
  opendir my $SPRITES, $directory or die "opendir $directory: $!";

  for my $file (sort { $a cmp $b } readdir $SPRITES) {
    next unless $file =~ /\.(jpe?g|png)$/i;
    my $tile = Imager->new(file => File::Spec->catfile($directory, $file))
      or die Imager->errstr;
    my $cn = $file;
    my ($w, $h) = ($tile->getwidth, $tile->getheight);
    $cn =~ s!\.\w+$!!;
    $cn =~ s!\W!-!g;
    $css
      .= ".$name.$cn { background-position: 0 -$size[1]px; width: ${w}px; height: ${h}px; }\n";
    warn "[AssetPack] Adding $directory/$file to sprite $name.png $w x $h\n" if DEBUG;
    $tiled->paste(src => $tile, left => 0, top => $size[1]) or die $tiled->errstr;
    $size[1] += $h;
    $size[0] = $w if $size[0] < $w;
  }

  $tiled->crop(right => $size[0], bottom => $size[1])
    ->write(data => \my $sprite, type => 'png')
    or die $tiled->errstr;
  $checksum = Mojo::Util::md5_sum($sprite);
  $css
    .= ".$name { background: url($name-$checksum.png) no-repeat; display: inline-block; }\n";
  $assetpack->_asset("$name-$checksum.png")->spurt($sprite);
  $assetpack->_asset("$name.css")->spurt($css);
}

sub _imager {
  my $self = shift;
  require Imager::File::PNG;
  Imager->new(@_);
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::AssetPack::Handler::Sprites - DEPRECATED

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Handler::Sprites> will be DEPRECATED.

See also L<https://github.com/jhthorsen/mojolicious-plugin-assetpack/issues/76>.

=head2 asset_for

=head1 SEE ALSO

L<Mojolicious::Plugin::AssetPack>.

=cut
