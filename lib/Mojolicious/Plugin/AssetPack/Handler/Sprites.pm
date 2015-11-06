package Mojolicious::Plugin::AssetPack::Handler::Sprites;

=head1 NAME

Mojolicious::Plugin::AssetPack::Handler::Sprites - A URL handler for sprites:// assets

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Handler::Sprites> is a module that can
generate sprites from image files in a directory.

This module requires L<Imager> and L<Imager::File::PNG> to work. Below you can
see how to install it on Debian or Ubuntu:

  $ apt-get install libpng12-dev
  $ cpanm Imager::File::PNG

This class is EXPERIMENTAL.

=cut

use Mojo::Base -base;
use File::Basename 'basename';
use constant DEBUG => $ENV{MOJO_ASSETPACK_DEBUG} || 0;

=head1 ATTRIBUTES

=head2 asset_for

  $asset = $self->asset_for($url, $assetpack);

This method finds images in the location specified in the C<$url>, and
generates a L<sprite|http://en.wikipedia.org/wiki/Sprite_%28computer_graphics%29#Sprites_by_CSS>.

The returning C<$asset> contains CSS with classnames describing how to use
each image. Example with C<$url> set to "sprites:///images/xyz".

  .xyz { background: url(xyz-5200164c30fb8660952969caf0cefa3d.png) no-repeat; display: inline-block; }
  .xyz.social-rss { background-position: 0px -0px; width: 34px; height: 30px; }
  .xyz.social-github { background-position: 0px -30px; width: 40px; height: 40px; }
  .xyz.social-chrome { background-position: 0px -70px; width: 32px; height: 32px; }

=cut

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
    my $tile = Imager->new(file => File::Spec->catfile($directory, $file)) or die Imager->errstr;
    my $cn = $file;
    my ($w, $h) = ($tile->getwidth, $tile->getheight);
    $cn =~ s!\.\w+$!!;
    $cn =~ s!\W!-!g;
    $css .= ".$name.$cn { background-position: 0 -$size[1]px; width: ${w}px; height: ${h}px; }\n";
    warn "[AssetPack] Adding $directory/$file to sprite $name.png $w x $h\n" if DEBUG;
    $tiled->paste(src => $tile, left => 0, top => $size[1]) or die $tiled->errstr;
    $size[1] += $h;
    $size[0] = $w if $size[0] < $w;
  }

  $tiled->crop(right => $size[0], bottom => $size[1])->write(data => \my $sprite, type => 'png') or die $tiled->errstr;
  $checksum = Mojo::Util::md5_sum($sprite);
  $css .= ".$name { background: url($name-$checksum.png) no-repeat; display: inline-block; }\n";
  $assetpack->_asset("$name-$checksum.png")->spurt($sprite);
  $assetpack->_asset("$name.css")->spurt($css);
}

sub _imager {
  my $self = shift;
  require Imager::File::PNG;
  Imager->new(@_);
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
