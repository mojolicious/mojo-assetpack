use t::Helper;

{
  my $t = t::Helper->t({minify => 0});
  ok $t->app->asset->preprocessors->can_process('js'), 'found preprocessor for js';
  $t->app->asset('app.js' => '/js/a.js', '/js/b.js');

  is_deeply(
    [$t->app->asset->get('app.js')],
    ['/packed/a-278ce8b881b15d1972024a8e9ece6799.js', '/packed/b-99eec25eb4441cda45d464c03b92a536.js'],
    'get(app.js)'
  );

  $t->get_ok('/test1')->status_is(200)->text_like('script', qr{w\.console\.log\('a'\);.*w\.console\.log\('b'\);}s)
    ->text_like('script', qr{window\)\);\n\(function\(w}s);
}

{
  my $t = t::Helper->t({minify => 1});
  $t->app->asset('app.js' => '/js/a.js', '/js/b.js');

  $t->get_ok('/test1');    # trigger pack_javascripts() twice for coverage
  $t->get_ok('/test1')->status_is(200)->text_like('script', qr{w\.console\.log\('a'\);.*w\.console\.log\('b'\);}s)
    ->text_like('script', qr{window\)\);\n\(function\(w}s);

  is_deeply([$t->app->asset->get('app.js')], ['/packed/app-a6621ccbdb4f3325dcfa3e9f85a61af0.min.js'], 'get(app.js)');
}

{
  no warnings 'redefine';
  my $minify = \&JavaScript::Minifier::XS::minify;
  *JavaScript::Minifier::XS::minify = sub {
    push @main::CALLED, $_[0];
    $minify->(@_);
  };

  my $t = t::Helper->t({minify => 1});

  $t->app->defaults(inline_ap => 0);
  $t->app->asset('app.js' => '/js/a.js', '/js/https___patform_twitter_com_widgets.js');

  $t->get_ok('/test1')->status_is(200)
    ->content_like(qr{<script src="/packed/app-2ca5e83a205231418d7ec9b120ccc802\.min\.js"}m);

  is int @main::CALLED, 1, 'minify called once';    # or diag Data::Dumper::Dumper(\@main::CALLED);
  like $main::CALLED[0], qr{'a'}, 'a.js got compiled';

  $t->get_ok('/packed/app-2ca5e83a205231418d7ec9b120ccc802.min.js')->status_is(200)
    ->content_like(qr/w\.console\.log\('a'\);\}\(window\)\);\n\/\*\n\s\* Skip JavaScript header\n/);
}

done_testing;

__DATA__
@@ test1.html.ep
%= asset 'app.js', {inline => stash('inline_ap')//1}
