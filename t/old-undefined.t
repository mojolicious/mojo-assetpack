use t::Helper;

my $t = t::Helper->t({minify => 0});

$t->get_ok('/test1')->status_is(200)->content_like(qr{<!-- Asset 'undefined\.css' is not defined\. -->});

done_testing;

__DATA__
@@ test1.html.ep
%= asset 'undefined.css'
