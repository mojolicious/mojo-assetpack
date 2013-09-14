use warnings;
use strict;
use Test::More;
use Test::Mojo;

plan skip_all => 'Not ready for alien host' unless $^O eq 'linux';

{
  use Mojolicious::Lite;
  plugin 'AssetPack';
}

my $t = Test::Mojo->new;
my $less = qx{which lessc}; chomp $less;
my $sass = qx{which sass}; chomp $sass;
my $yuicompressor = qx{which yuicompressor}; chomp $yuicompressor;

{
  is $Mojolicious::Plugin::AssetPack::APPLICATIONS{less}, $less, 'found less';
  is $Mojolicious::Plugin::AssetPack::APPLICATIONS{sass}, $sass, 'found sass';
  is $Mojolicious::Plugin::AssetPack::APPLICATIONS{yuicompressor}, $yuicompressor, 'found yuicompressor';
}

done_testing;
