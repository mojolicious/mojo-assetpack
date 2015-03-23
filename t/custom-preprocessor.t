use t::Helper;

{
  my $t = t::Helper->t({minify => 1});
  my $cwd = 'UNDEFINED';

  $t->app->asset->preprocessors->remove('js');
  $t->app->asset->preprocessors->add(
    js => sub {
      my ($assetpack, $text, $file) = @_;
      $$text = 'var too = "cool";';
      $cwd   = Cwd::getcwd;
    }
  );

  $t->app->asset('app.js' => '/js/a.js');

  like $cwd, qr{public/js}, 'changed dir';

  $t->get_ok('/test1')->status_is(200)
    ->content_like(qr{<script src="/packed/app-527b09c38362b669ec6e16c00d9fb30d\.min\.js"}m);

  $t->get_ok($t->tx->res->dom->at('script')->{src})->status_is(200)->content_is('var too = "cool";');
}

done_testing;

__DATA__
@@ test1.html.ep
%= asset 'app.js'
