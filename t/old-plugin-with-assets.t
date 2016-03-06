use t::Helper;
use File::Find ();
use File::Spec::Functions qw( catdir catfile );

plan skip_all => 'Cannot chmod on Win32' if $^O eq 'Win32';

my $source_dir   = catdir qw( t read-only-with-source-assets );
my $existing_dir = catdir qw( t read-only-with-existing-assets );
my $plugin_name  = make_plugin();
my $t            = Test::Mojo->new(Mojolicious->new);

chmod_assets(0555) or plan skip_all => "Unable to chmod 0555 $source_dir, $existing_dir";

# set up app
$t->app->mode('production');
$t->app->log->on(message => sub { warn "[$_[1]] $_[2]\n" }) if $ENV{HARNESS_IS_VERBOSE};
$t->app->static->paths([catdir qw( t public )]);
$t->app->routes->get('/test1' => 'test1');
$t->app->plugin('AssetPack');

# undefined asset
$t->get_ok('/test1')->status_is(200)->content_like(qr(Asset 'my-plugin-existing.css' is not defined));

# define asset
$t->app->plugin($plugin_name);
$t->get_ok('/test1')->status_is(200)->content_like(qr/body\{color:\#aaa\}body\{color:\#aaa\}/);

# make sure we did not create a new asset
ok !-e catfile(qw( t public packed my-plugin-existing-7c174b801d6fc968f1576055e88c18cb.css )), 'using existing asset';

chmod_assets(0775);
done_testing;

sub chmod_assets {
  my $mode = $_[0];
  my @success;

  File::Find::find(
    sub {
      my $m = -d $_ ? $mode : $mode & 0666;
      push @success, chmod $m, $_;
    },
    $source_dir,
    $existing_dir
  );

  return 0 if grep { !$_ } @success;
  return 1;
}

sub make_plugin {
  eval <<"HERE" or die $@;
package t::SomePluginWithAssets;
use Mojolicious::Plugin::AssetPack;
use Mojo::Base 'Mojolicious::Plugin';

sub register {
  my (\$self, \$app, \$config) = \@_;

  \$app->plugin('AssetPack') unless eval { \$app->asset };

  push \@{\$app->static->paths}, "$existing_dir";
  push \@{\$app->asset->source_paths}, "$source_dir";
  \$app->asset('my-plugin-existing.css' => qw( /css/my-plugin-a.css /css/my-plugin-a.css ));
}
__PACKAGE__;
HERE
}

__DATA__
@@ test1.html.ep
%= asset 'my-plugin-existing.css', { inline => 1 }
