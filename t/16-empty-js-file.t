use t::Helper;

# Looks like JavaScript-Minifier-XS returns undef if no javascript was found:
# https://metacpan.org/source/GTERMARS/JavaScript-Minifier-XS-0.09/t/03-minifies-to-nothing.t

my @warn;
$SIG{__WARN__} = sub { push @warn, $_[0]; warn $_[0]; };

{
  my $t = t::Helper->t({ minify => 1 });

  $t->app->asset('e.js' => '/js/empty.js');
  $t->get_ok($t->app->asset->get('e.js'))->content_is('');
  is_deeply \@warn, [], 'no warnings from JavaScript-Minifier-XS';
}

done_testing;

__DATA__
@@ empty-js-file.html.ep
%= asset 'e.js'
