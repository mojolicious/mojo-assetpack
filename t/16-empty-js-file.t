use t::Helper;

# Looks like JavaScript-Minifier-XS returns undef if no javascript was found:
# https://metacpan.org/source/GTERMARS/JavaScript-Minifier-XS-0.09/t/03-minifies-to-nothing.t

my ($file, @warn);
$SIG{__WARN__} = sub { push @warn, $_[0]; warn $_[0]; };

my $t = t::Helper->t({minify => 1});

$t->app->asset('e.js' => '/js/empty.js');
($file) = $t->app->asset->get('e.js');
$t->get_ok($file)->content_is('');
is_deeply \@warn, [], 'no warnings from JavaScript-Minifier-XS';

done_testing;
