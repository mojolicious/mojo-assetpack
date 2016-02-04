use t::Helper;

my $t = t::Helper->t_old({minify => 0});

plan skip_all => $@ unless eval 'require Imager::File::PNG;1';

$t->app->asset('my-sprites.css' => 'sprites:///images/xyz', '/test.css');

$t->get_ok('/test1')
  ->text_like('style', qr/\.xyz\.social-chrome \{ background-position: 0 -0px; width: 32px; height: 32px; \}/)
  ->text_like('style', qr/\.xyz\.social-github \{ background-position: 0 -32px; width: 40px; height: 40px; \}/)
  ->text_like('style', qr/\.xyz\.social-rss \{ background-position: 0 -72px; width: 34px; height: 30px; \}/)
  ->text_like('style', qr/\.xyz \{ background: url\(xyz-\w+\.png\) no-repeat; display: inline-block; \}/);

done_testing;

__DATA__
@@ test.css
.xyz { display: block; }
@@ test1.html.ep
%= asset 'my-sprites.css', {inline => 1}
