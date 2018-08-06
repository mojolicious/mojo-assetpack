use Test::More;
use Mojo::JSON qw(false true);
use Mojolicious::Plugin::AssetPack::Asset;
use Mojolicious::Plugin::AssetPack::Pipe::Favicon;

my $favicon = Mojolicious::Plugin::AssetPack::Pipe::Favicon->new(api_key => 'abc');
my $icon = Mojolicious::Plugin::AssetPack::Asset->new(content => '12345');

is_deeply(
  $favicon->_normalize_request(
    {
      android_chrome => {manifest => {orientation => 'portrait'}},
      firefox_app       => {circle_inner_margin => 5, keep_picture_in_circle => true, picture_aspect => 'circle'},
      ios               => {},
      safari_pinned_tab => {},
      windows           => {},
      blueprint         => {
        app_name         => 'My sample app',
        background_color => '#456789',
        description      => 'Yet another sample application',
        developer_name   => 'Philippe Bernard',
        developer_url    => 'http://stackoverflow.com/users/499917/philippe-b',
        theme_color      => '#4972ab',
      }
    },
    $icon
  ),
  {
    favicon_generation => {
      api_key        => 'abc',
      files_location => {type => 'path', path => '/asset'},
      versioning     => false,
      master_picture => {content => "MTIzNDU=\n", type => 'inline'},
      settings       => {error_on_image_too_small => true},
      favicon_design => {
        android_chrome => {
          manifest =>
            {display => 'standalone', name => 'My sample app', orientation => 'portrait', theme_color => '#4972ab'},
          picture_aspect => 'shadow',
        },
        firefox_app => {
          background_color    => '#456789',
          circle_inner_margin => 5,
          manifest            => {
            app_description => 'Yet another sample application',
            app_name        => 'My sample app',
            developer_name  => 'Philippe Bernard',
            developer_url   => 'http://stackoverflow.com/users/499917/philippe-b',
          },
          picture_aspect         => 'circle',
          keep_picture_in_circle => true,
        },
        ios => {
          app_name         => 'My sample app',
          background_color => '#456789',
          picture_aspect   => 'background_and_margin',
          margin           => 4,
        },
        safari_pinned_tab => {picture_aspect => 'black_and_white', theme_color => '#4972ab'},
        windows           => {
          app_name         => 'My sample app',
          background_color => '#456789',
          picture_aspect   => 'white_silhouette',
          assets           => {
            windows_80_ie_10_tile       => true,
            windows_10_ie_11_edge_tiles => {big => true, medium => true, rectangle => false, small => false},
          }
        },
      },
    }
  },
  'set design defaults'
);

done_testing;

__DATA__
@@ index.html.ep
favicon!
%= asset 'favicon.ico'
