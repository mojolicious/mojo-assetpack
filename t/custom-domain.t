use t::Helper;

{
  local $TODO = "Not sure if expanded files should be served from custom base_url";

  diag 'minify=0';
  my $t = t::Helper->t({ minify => 0, base_url => "http://example.com/static/" });

  $t->app->asset('app.css' => '/css/a.css');
  $t->get_ok('/custom-domain')->status_is(200)->content_like(qr{<link href="http://example\.com/static/css/a\.css"}, 'http://example.com/static/');
}

{
  diag 'minify=1';
  my $t = t::Helper->t({ minify => 1, base_url => "http://example.com/minified/" });

  $t->app->asset('app.css' => '/css/a.css');
  $t->get_ok('/custom-domain')->status_is(200)->content_like(qr{<link href="http://example\.com/minified/app-\w+\.css"}, 'http://example\.com/minified/');
}

done_testing;

__DATA__
@@ custom-domain.html.ep
%= asset 'app.css'
