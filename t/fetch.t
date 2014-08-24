use t::Helper;

plan skip_all => 'TEST_ONLINE=1 required' unless $ENV{TEST_ONLINE};

my $t = t::Helper->t;
my $cdn_base_url = 'http://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.1.0';

{
  use File::Basename 'basename';

  # preprocessors to expend the url() definitions in the css file downloaded from the CDN
  $t->app->asset->preprocessors->add(css => sub {
    my ($assetpack, $text, $file) = @_;
    my $fetch = sub {
      my $url = "$cdn_base_url/$1";
      my $path = $assetpack->fetch($url);
      return sprintf "url('%s')", basename $path;
    };

    $$text =~ s!url\('..([^']+)'\)!{ $fetch->() }!ge if $file =~ /awesome/;
  });

  # define the asset to be fetched from the CDN
  $t->app->asset("app.css" => "$cdn_base_url/css/font-awesome.css");
}

{
  $t->get_ok('/fetch')->status_is(200)->content_like(qr{href="/packed/font-awesome-\w+\.css".*}m);
  $t->get_ok($t->tx->res->dom->at('link')->{href})
    ->status_is(200)
    ->content_like(qr{url\('http___cdnjs_cloudflare_com_ajax_libs_font-awesome_4_1_0__fonts_fontawesome-webfont_eot_v_4_1_0\.eot'\)}, 'eot')
    ->content_like(qr{url\('http___cdnjs_cloudflare_com_ajax_libs_font-awesome_4_1_0__fonts_fontawesome-webfont_eot__iefix_v_4_1_0\.eot'\)}, 'iefix')
    ->content_like(qr{url\('http___cdnjs_cloudflare_com_ajax_libs_font-awesome_4_1_0__fonts_fontawesome-webfont_woff_v_4_1_0\.woff'\)}, 'woff')
    ->content_like(qr{url\('http___cdnjs_cloudflare_com_ajax_libs_font-awesome_4_1_0__fonts_fontawesome-webfont_ttf_v_4_1_0\.ttf'\)}, 'ttf')
    ->content_like(qr{url\('http___cdnjs_cloudflare_com_ajax_libs_font-awesome_4_1_0__fonts_fontawesome-webfont_svg_v_4_1_0_fontawesomeregular\.svg'\)}, 'svg')
    ;
}

done_testing;

__DATA__
@@ fetch.html.ep
%= asset 'app.css'
