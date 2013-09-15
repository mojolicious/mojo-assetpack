use warnings;
use strict;
use Test::More;
use Test::Mojo;

plan skip_all => 'Not ready for alien host' unless $^O eq 'linux';
plan skip_all => 'Not ready for alien host' unless eval "require JavaScript::Minifier::XS; 1";

{
  use Mojolicious::Lite;
  plugin 'AssetPack' => { minify => 1, rebuild => 1 };

  app->asset->preprocessor(js => sub {
    my($self, $file) = @_;
    return JavaScript::Minifier::XS::minify(Mojo::Util::slurp($file)) if $self->minify;
    return;
  });
  app->asset('app.js' => '/js/a.js', '/js/b.js');

  get '/js' => 'js';
}

plan skip_all => 't/public/packed' unless -d 't/public/packed';

my $t = Test::Mojo->new;
my $ts = $^T;

{
  $t->get_ok('/js'); # trigger pack_javascripts() twice for coverage
  $t->get_ok('/js')
    ->status_is(200)
    ->content_like(qr{<script src="/packed/app\.$ts\.js".*}m)
    ;
  $t->get_ok("/packed/app.$ts.js")->status_is(200);
}

done_testing;
__DATA__
@@ js.html.ep
%= asset 'app.js'
@@ less.html.ep
%= asset 'less.css'
@@ sass.html.ep
%= asset 'sass.css'
@@ css.html.ep
%= asset 'app.css'
