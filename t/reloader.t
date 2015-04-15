use t::Helper;
my $t = t::Helper->t({minify => 0, reloader => {}});

$t->get_ok('/test1')->status_is(200)->element_exists('script[src="/packed/reloader.js"]');

local $TODO = 'inline is not yet supported';
$t->text_like('script', qr{new WebSocket});

done_testing;

__DATA__
@@ test1.html.ep
%= asset 'reloader.js', {inline => 1}
%= asset 'reloader.js';
