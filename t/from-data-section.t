use t::Helper;

my $t = t::Helper->t({minify => 0});

$t->app->asset('app.css' => '/from/data/section.css', '/css/c.css');
$t->get_ok('/test1')->status_is(200)->content_like(qr{div\.data-section})->content_like(qr{c1c1c1});

done_testing;

__DATA__
@@ test1.html.ep
%= asset 'app.css', {inline => 1}

@@ from/data/section.css
div.data-section { background: #666; }
