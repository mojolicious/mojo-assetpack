use t::Helper;

my $t = t::Helper->t({minify => 1});
eval { $t->app->asset('app.css' => 'http://12345678987654324567.example.com/this/should/never/work/8765434567'); };
like $@, qr{could not be fetched}, 'failed to download asset';

done_testing;
