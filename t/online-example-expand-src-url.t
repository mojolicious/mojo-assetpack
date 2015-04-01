use t::Helper;

plan skip_all => 'TEST_ONLINE=1 required' unless $ENV{TEST_ONLINE};

my $t            = t::Helper->t;
my $cdn_base_url = 'http://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.1.0';

{
  # preprocessors to expand the url() definitions in the css file downloaded from the CDN
  $t->app->asset->preprocessors->add(
    css => sub {
      my ($assetpack, $text, $file) = @_;
      $$text =~ s!url\('../!url('$cdn_base_url/!g if $file =~ /awesome/;
    }
  );

  # define the asset to be fetched from the CDN
  $t->app->asset("app.css" => "$cdn_base_url/css/font-awesome.css");
}

{
  $t->get_ok('/test1')->status_is(200)
    ->content_like(
    qr{href="/packed/http___cdnjs_cloudflare_com_ajax_libs_font-awesome_4_1_0_css_font-awesome_css-\w+\.css"}m);

  $t->get_ok($t->tx->res->dom->at('link')->{href})->status_is(200)
    ->content_like(qr{url\('$cdn_base_url/fonts/fontawesome-webfont\.eot\?v=4\.1\.0'\);},                    'eot')
    ->content_like(qr{url\('$cdn_base_url/fonts/fontawesome-webfont\.eot\?\#iefix&v=4\.1\.0'\)},             'iefix')
    ->content_like(qr{url\('$cdn_base_url/fonts/fontawesome-webfont\.woff\?v=4\.1\.0'\)},                    'woff')
    ->content_like(qr{url\('$cdn_base_url/fonts/fontawesome-webfont\.ttf\?v=4\.1\.0'\)},                     'ttf')
    ->content_like(qr{url\('$cdn_base_url/fonts/fontawesome-webfont\.svg\?v=4\.1\.0\#fontawesomeregular'\)}, 'svg');
}

done_testing;

__DATA__
@@ test1.html.ep
%= asset 'app.css'
