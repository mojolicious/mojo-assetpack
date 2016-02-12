use t::Helper;

my $t = t::Helper->t({minify => 0});
plan skip_all => 'CSS::Sass is required' unless eval 'require CSS::Sass;';
plan skip_all => 'Could not find preprocessors for sass' unless $t->app->asset->preprocessors->can_process('sass');

local $TODO = 'https://github.com/jhthorsen/mojolicious-plugin-assetpack/issues/70';

eval { $t->app->asset('scss.css' => '/sass/70-utf8.scss') };
is $@, '', 'built scss.css';

$t->get_ok('/test1')->status_is(200)->content_like(qr{コメント});

done_testing;
__DATA__
@@ test1.html.ep
%= asset 'scss.css', {inline => 1}
