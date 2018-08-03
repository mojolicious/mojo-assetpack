use lib '.';
use t::Helper;

$ENV{MOJO_MODE} = 'not_development';
my $t = t::Helper->t(pipes => ['Combine']);

$t->app->helper(
  'some.mojo.helper' => sub {
    my ($c, $name, $args) = @_;
    $args->{val} ||= 'red';
    return {content => "$name:monospace;\n", format => 'css'} unless $args->{format};
    return "$name:$args->{val};\n";
  }
);

$t->app->asset->process;
$t->get_ok('/')->status_is(200)->element_count_is('link', 1);
$t->get_ok($t->tx->res->dom->at('link')->{href})->status_is(200)->content_like(qr{border:1px;})
  ->content_like(qr{color:red;})->content_like(qr{font:monospace;});

done_testing;

__DATA__
@@ index.html.ep
%= asset 'app.css'
@@ assetpack.def
! app.css
< helper://some.mojo.helper/border?format=css&val=1px
< helper://some.mojo.helper/color?format=css
< helper://some.mojo.helper/font
