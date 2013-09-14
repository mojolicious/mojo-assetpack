use ExtUtils::MakeMaker;
WriteMakefile(
  NAME => 'Mojolicious::Plugin::Compress',
  ABSTRACT_FROM => 'lib/Mojolicious/Plugin/Compress.pm',
  VERSION_FROM => 'lib/Mojolicious/Plugin/Compress.pm',
  AUTHOR => 'Jan Henning Thorsen <jhthorsen@cpan.org>',
  LICENSE => 'perl',
  PREREQ_PM => {
    'Mojolicious' => '4.30',
    'File::Which' => '1.00',
  },
  BUILD_REQUIRES => {
    'Test::More' => '0.90',
  },
  META_MERGE => {
    resources => {
      license => 'http://dev.perl.org/licenses/',
      homepage => 'https://metacpan.org/release/Mojolicious-Plugin-Compress',
      bugtracker => 'http://rt.cpan.org/NoAuth/Bugs.html?Dist=Mojolicious-Plugin-Compress',
      repository => 'https://github.com/jhthorsen/mojolicious-plugin-compress',
    },
  },
  test => {
    TESTS => 't/*.t',
  },
);
