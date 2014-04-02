use warnings;
use strict;
use Test::More;
use Test::Mojo;
use File::Copy;
use FindBin;

plan skip_all => 'Not ready for alien host' unless $^O eq 'linux';
plan tests => 12 * 2;

unlink glob 't/public/packed/*';

my $assetpack;

sub test_reprocess {
  my %args = @_;

  {
    use Mojolicious::Lite;
    plugin 'AssetPack' => {
      minify => 0, reprocess => $args{reprocess}
    };

    app->asset('coffee.js' => '/reprocess/current.coffee');
    $assetpack = app->asset;

    get '/coffee' => 'coffee';
  }

  my $t = Test::Mojo->new;

 SKIP: {
    skip 'Could not find preprocessors for coffee', 12 unless $assetpack->preprocessors->has_subscribers('coffee');

    $t->get_ok('/coffee')
      ->status_is(200)
      ->content_like(qr{<script src="/packed/current-\w+\.js"}s)
      ;

    $t->get_ok($t->tx->res->dom->at('script')->{src})
      ->status_is(200)
      ->content_like(qr{console\.log\(['"]current})
      ;

    # Simulate changing the file in development.
    copy("$FindBin::Bin/public/reprocess/new.coffee",
         "$FindBin::Bin/public/reprocess/current.coffee");

    $t->get_ok('/coffee')
      ->status_is(200)
        ->content_like(qr{<script src="/packed/current-\w+\.js"}s)
          ;

    my $new_text = $args{new_text};
    $t->get_ok($t->tx->res->dom->at('script')->{src})
      ->status_is(200)
      ->content_like(qr{console\.log\(['"]$new_text})
      ;

    # Return the filesystem to original state.
    copy("$FindBin::Bin/public/reprocess/current.coffee.original",
         "$FindBin::Bin/public/reprocess/current.coffee");

  }
}

test_reprocess(reprocess => 1, new_text => 'new');
test_reprocess(reprocess => 0, new_text => 'current');

__DATA__
@@ coffee.html.ep
%= asset 'coffee.js'
