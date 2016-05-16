use t::Helper;

my $file   = Mojo::Asset::File->new(path => 't/assets/t-reloader.scss');
my $import = Mojo::Asset::File->new(path => 't/assets/_t-reloader-import.scss');
eval { $import->add_chunk("body{color:#000;}\n") }
  or plan skip_all => "_t-reloader-import.scss: $!";
eval { $file->add_chunk("\@import 't-reloader-import.scss';\n") }
  or plan skip_all => "t-reloader.scss: $!";

my $t = t::Helper->t(pipes => [qw(Reloader Sass Css Combine)]);
my $asset = $t->app->asset->store->asset('t-reloader.scss');
$t->app->asset->process('app.css' => $asset);

is_deeply(
  $t->app->asset->pipe('Reloader')->watch,
  {
    'app.css' => [
      map { $t->app->home . "/assets/$_" } "t-reloader.scss", "_t-reloader-import.scss",
    ]
  }
);

done_testing;
__DATA__
@@ index.html.ep
%= asset 'app.css'

