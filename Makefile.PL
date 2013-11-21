use ExtUtils::MakeMaker;
WriteMakefile(
  NAME => 'Mojolicious::Plugin::AssetPack',
  ABSTRACT_FROM => 'lib/Mojolicious/Plugin/AssetPack.pm',
  VERSION_FROM => 'lib/Mojolicious/Plugin/AssetPack.pm',
  AUTHOR => 'Jan Henning Thorsen <jhthorsen@cpan.org>',
  LICENSE => 'perl',
  PREREQ_PM => {
    'CSS::Minifier::XS' => '0.01',
    'File::Which' => '1.00',
    'IPC::Run3' => '0.04',
    'JavaScript::Minifier::XS' => '0.01',
    'Mojolicious' => '4.30',
  },
  BUILD_REQUIRES => {
    'Test::More' => '0.90',
  },
  META_MERGE => {
    resources => {
      license => 'http://dev.perl.org/licenses/',
      homepage => 'https://metacpan.org/release/Mojolicious-Plugin-AssetPack',
      bugtracker => 'http://rt.cpan.org/NoAuth/Bugs.html?Dist=Mojolicious-Plugin-AssetPack',
      repository => 'https://github.com/jhthorsen/mojolicious-plugin-assetpack',
    },
  },
  test => {
    TESTS => 't/*.t',
  },
);
