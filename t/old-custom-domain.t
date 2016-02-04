use t::Helper;

my $t = t::Helper->t_old({minify => 0, base_url => "http://example.com/static/"});
$t->app->asset('app.css' => '/css/a.css');

$t->get_ok('/test1')->status_is(200)
  ->element_exists('[href="http://example.com/static/a-09a653553edca03ad3308a868e5a06ac.css"]');

$t = t::Helper->t_old({minify => 1, base_url => "http://example.com/minified/"});
$t->app->asset('app.css' => '/css/a.css');
$t->get_ok('/test1')->status_is(200)
  ->content_like(qr{<link href="http://example\.com/minified/app-\w+\.min\.css"}, 'http://example\.com/minified/');

done_testing;

__DATA__
@@ test1.html.ep
%= asset 'app.css'
