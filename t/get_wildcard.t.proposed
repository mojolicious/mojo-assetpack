use t::Helper;
my $t = t::Helper->t( { minify => 0 } );
my $assetpack = $t->app->asset;
my @data;


$t->app->asset( 'app.css' => '/css/a.css', '/css/b.css', '/css/*.css' );


my @files
    = qw(/packed/a-09a653553edca03ad3308a868e5a06ac.css /packed/b-89dbc5a64c4e7e64a3d1ce177b740a7e.css /packed/bootstrap-0cbacb97f7b3f70fb6d39926d48dba68-bcf8c4d10ca045af975cc9b89b2c4780.css /packed/c-b59b871d321a30fc1d6ade3d456d8b7f.css /packed/d-42368a9cbff256c6ba3ef0b885205c8f.css);

foreach my $file (@files) {
    ok( grep( /^$file$/, $assetpack->get('app.css') ), "Found $file" );
}


@data = $assetpack->get( 'app.css', { inline => 1 } );
like $data[0], qr{background:\s*\#a1a1a1}, 'a.css';
like $data[1], qr{background:\s*\#b1b1b1}, 'b.css';

isa_ok( ( $assetpack->get( 'app.css', { assets => 1 } ) )[0], 'Mojolicious::Plugin::AssetPack::Asset' );

done_testing;

__DATA__
@@ css.html.ep
%= asset 'app.css'
