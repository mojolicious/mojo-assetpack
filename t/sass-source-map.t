use lib '.';
use t::Helper;
plan skip_all => 'cpanm CSS::Sass' unless eval 'use CSS::Sass 3.3.0;1';
plan skip_all => 'cpanm CSS::Sass' unless $ENV{TEST_SOURCE_MAPS};

my $t = t::Helper->t(pipes => [qw(Sass)]);
$t->app->asset->process('app.css' => 'sass/sass-1.scss');
$t->get_ok('/')->status_is(200)
  ->element_exists(qq(link[href="/asset/71dcf0669a/sass-1.css"]));

$t->get_ok('/asset/71dcf0669a/sass-1.css')->status_is(200)
  ->content_like(qr{sourceMappingURL=\.\./8f89310ec6/sass-1\.css\.map});
$t->get_ok('/asset/8f89310ec6/sass-1.css.map')->json_like('/file', qr{sass-1\.scss})
  ->json_has('/mappings')->json_has('/sources')->json_has('/version');

$ENV{MOJO_MODE} = 'development_required';
$t = t::Helper->t(pipes => [qw(Sass)]);
$t->app->asset->process('app.css' => 'sass/sass-1.scss');
$t->get_ok('/')->status_is(200)
  ->element_exists(qq(link[href="/asset/71dcf0669a/sass-1.css"]));
$t->get_ok('/asset/71dcf0669a/sass-1.css')->status_is(200)
  ->content_unlike(qr{sourceMappingURL});

done_testing;

__DATA__
@@ index.html.ep
%= asset 'app.css'
