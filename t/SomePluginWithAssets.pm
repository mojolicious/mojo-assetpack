package t::SomePluginWithAssets;
use Mojolicious::Plugin::AssetPack;
use File::Spec::Functions qw( catdir tmpdir );
use Mojo::Base 'Mojolicious::Plugin';

sub register {
  my ($self, $app, $config) = @_;

  $app->plugin('AssetPack');
  $app->asset('my-plugin-existing.css' => qw( /css/my-plugin-a.css /css/my-plugin-a.css ));
  $app->asset('my-plugin-new.css'      => qw( /css/my-plugin-b.css /css/my-plugin-b.css ));
}

1;
