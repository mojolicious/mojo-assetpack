use t::Helper;

my $t = t::Helper->t({minify => 0});
my $assetpack = $t->app->asset;
my @data;

$t->app->asset('app.css' => '/css/5w.css', '/css/*w.css');

is_deeply(
  [$assetpack->get('app.css')],
  [
    qw( /packed/5w-6a4be8014d0575886036b8362e385320.css /packed/1w-09a653553edca03ad3308a868e5a06ac.css /packed/2w-76f882600dc1f9f84a333a5979a41246.css )
  ],
  'get()'
);

my $css = join "\n", $assetpack->get('app.css', {inline => 1});
like $css, qr{\#a5a5a5.*\#a1a1a1.*\#a2a2a2}s, 'css in order';

done_testing;

__DATA__
@@ css.html.ep
%= asset 'app.css'
