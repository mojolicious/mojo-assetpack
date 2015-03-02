use Test::More;
use File::Find;

if (($ENV{HARNESS_PERL_SWITCHES} || '') =~ /Devel::Cover/) {
  plan skip_all => 'HARNESS_PERL_SWITCHES =~ /Devel::Cover/';
}
if (!eval 'use Test::Pod; 1') {
  *Test::Pod::pod_file_ok = sub {
    SKIP: { skip "pod_file_ok(@_) (Test::Pod is required)", 1 }
  };
}
if (!eval 'use Test::Pod::Coverage; 1') {
  *Test::Pod::Coverage::pod_coverage_ok = sub {
    SKIP: { skip "pod_coverage_ok(@_) (Test::Pod::Coverage is required)", 1 }
  };
}

find({wanted => sub { /\.(pm|pod)$/ and push @files, $File::Find::name }, no_chdir => 1}, -e 'blib' ? 'blib' : 'lib',);

my $n = 0;
$n += /\.pm$/ ? 3 : 1 for @files;
plan tests => $n;

for my $file (@files) {
  my $module = $file;
  $module =~ s,.*/?lib/,,;
  $module =~ s,/,::,g;

  Test::Pod::pod_file_ok($file);

  if ($module =~ s,\.pm$,,) {
    ok eval "use $module; 1", "use $module" or diag $@;
    Test::Pod::Coverage::pod_coverage_ok($module);
  }
}
