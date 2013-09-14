use ExtUtils::MakeMaker;
WriteMakefile(
  NAME => 'Mojolicious::Plugin::Compress',
  ABSTRACT_FROM => 'lib/Mojolicious/Plugin/Compress.pm',
  VERSION_FROM => 'lib/Mojolicious/Plugin/Compress.pm',
  AUTHOR => 'Jan Henning Thorsen <jhthorsen@cpan.org>',
  LICENSE => 'perl',
  PREREQ_PM => {

  },
  BUILD_REQUIRES => {

  },
  META_MERGE => {
    resources => {
      license => 'http://dev.perl.org/licenses/',
      homepage => 'https://metacpan.org/release/Mojolicious-Plugin-Compress',
      bugtracker => 'http://rt.cpan.org/NoAuth/Bugs.html?Dist=Mojolicious-Plugin-Compress',
      repository => 'origin',
     #MailingList => 'some-mailing@list.org',
    },
  },
  test => {
    TESTS => 't/*.t',
  },
  #MIN_PERL_VERSION => 5.10,
  #EXE_FILES => ['bin/my-app'],
);
