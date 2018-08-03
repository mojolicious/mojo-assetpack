use lib '.';
use t::Helper;

my $t = t::Helper->t(pipes => ['Css']);
is_deeply([sort { length $a <=> length $b } routes()], ['/'], 'one route');

$t->app->asset->process('app.css' => 'one.css');
is_deeply([sort { length $a <=> length $b } routes()], ['/', '/asset/:checksum/*name'], 'two routes');

done_testing;

sub routes {
  my $r = shift || $t->app->routes;
  return map { (($_->pattern->unparsed || '/'), routes($_)) } @{$r->children};
}

__DATA__
@@ one.css
.one { color: #000; }
