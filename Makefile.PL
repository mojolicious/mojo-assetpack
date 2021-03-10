use 5.016;

use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
  NAME          => 'Mojolicious::Plugin::AssetPack',
  AUTHOR        => 'Sebastian Riedel <sri@cpan.org>',
  LICENSE       => 'artistic_2',
  ABSTRACT_FROM => 'lib/Mojolicious/Plugin/AssetPack.pm',
  VERSION_FROM  => 'lib/Mojolicious/Plugin/AssetPack.pm',
  TEST_REQUIRES => {'Test::More'  => '0.88'},
  PREREQ_PM     => {'File::Which' => '1.21', 'IPC::Run3' => '0.048', 'Mojolicious' => '9.0'},
  META_MERGE    => {
    'dynamic_config' => 0,
    'meta-spec'      => {version => 2},
    'resources'      => {
      bugtracker => {web => 'https://github.com/mojolicious/mojo-assetpack/issues'},
      homepage   => 'https://github.com/mojolicious/mojo-assetpack',
      repository => {
        type => 'git',
        url  => 'https://github.com/mojolicious/mojo-assetpack.git',
        web  => 'https://github.com/mojolicious/mojo-assetpack',
      },
    },
  },
  test => {TESTS => (-e 'META.yml' ? 't/*.t' : 't/*.t xt/*.t')},
);
