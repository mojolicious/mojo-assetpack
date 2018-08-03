package Mojolicious::Plugin::AssetPack::Pipe::Favicon;
use Mojo::Base 'Mojolicious::Plugin::AssetPack::Pipe';

use Mojo::DOM;
use Mojo::JSON qw(false true);
use Mojo::Template;
use Mojo::Util;
use Mojolicious::Plugin::AssetPack::Util 'checksum';

# this should be considered private
use constant API_URL => $ENV{MOJO_ASSETPACK_FAVICON_API_URL} || 'https://realfavicongenerator.net/api/favicon';

has api_key  => sub { die 'api_key() must be set' };
has design   => sub { shift->_build_design };
has settings => sub { +{error_on_image_too_small => Mojo::JSON->true} };

sub process {
  my ($self, $assets) = @_;
  return unless $self->topic =~ m!^favicon(\.\w+)?\.ico$!;

  my $store = $self->assetpack->store;
  my $asset = $assets->first;
  my $attrs = $asset->TO_JSON;
  my ($urls, $markup, %sub_assets);

  $attrs->{key} = checksum(Mojo::JSON::encode_json($self->design))
    or die '[AssetPack] Invalid pipe("Favicon")->design({})';

  if (my $db = $store->load($attrs)) {
    ($urls, $markup) = split /__MARKUP__/, $db->content;
    $urls = [grep {/\w/} split /\n/, $urls];
  }
  else {
    ($urls, $markup) = $self->_fetch($asset);
    $db = join "\n", @$urls, __MARKUP__ => $markup;
    $store->save(\$db, $attrs);
  }

  my $renderer = sub {
    my ($asset, $c, $args, @attrs) = @_;
    my $content = $asset->content;
    $content =~ s!"/([^.]+\.\w{3,})"!sprintf '"%s"', $sub_assets{$1} ? $sub_assets{$1}->url_for($c) : $1!ge;
    return $content if $args;
    return $c->render(data => $content);
  };

  for my $url (@$urls) {
    my $asset = $store->asset($url) or die "AssetPack was unable to fetch icons/assets asset $url";
    $sub_assets{join '.', $asset->name, $asset->format} = $asset;
    $asset->renderer($renderer) if $asset->format =~ m!(manifest|xml|webapp)$!;
    $self->assetpack->{by_checksum}{$asset->checksum} = $asset;
  }

  unless ($markup =~ m!msapplication-config!) {
    $markup =~ s![\r\n]+$!!;
    $markup .= qq(\n<meta name="msapplication-config" content="/browserconfig.xml">);
  }

  $asset->content($markup)->tag_for($renderer);
}

sub _build_design {
  my $self        = shift;
  my $name        = ref $self->app;
  my $bg_color    = '#F5F5F5';
  my $theme_color = '#536DFE';

  return {
    desktop_browser => {},
    android_chrome  => {
      manifest       => {display => 'standalone', name => $name, orientation => 'portrait'},
      picture_aspect => 'shadow',
      theme_color    => $theme_color,
    },
    firefox_app => {
      background_color       => $bg_color,
      circle_inner_margin    => '5',
      keep_picture_in_circle => 'true',
      picture_aspect         => 'circle',
      manifest               => {app_description => '', app_name => $name, developer_name => '', developer_url => '',}
    },
    ios => {background_color => $bg_color, margin => '4', picture_aspect => 'background_and_margin',},
    safari_pinned_tab => {picture_aspect => 'black_and_white', threshold => 60, theme_color => $theme_color,},
    windows           => {
      background_color => $theme_color,
      picture_aspect   => "white_silhouette",
      assets           => {
        windows_80_ie_10_tile       => true,
        windows_10_ie_11_edge_tiles => {big => true, medium => true, rectangle => false, small => false},
      }
    },
  };
}

sub _fetch {
  my ($self, $asset) = @_;
  $self->assetpack->ua->inactivity_timeout(60);
  my $res = $self->assetpack->ua->post(API_URL, json => $self->_request($asset))->res;

  unless ($res->code eq '200') {
    my $json = $res->json || {};
    die sprintf '[AssetPack] Could not generate favicon: %s',
      $json->{favicon_generation_result}{result}{error_message} || $res->error->{message};
  }

  my $data   = $res->json->{favicon_generation_result}{favicon};
  my $files  = $data->{files_urls} || [];
  my $markup = $data->{html_code} or die qq|[AssetPack] No html_code generated. Invalid pipe("Favicon")->design({})..?|;
  return ($files, $markup) if @$files;
  die qq|[AssetPack] No favicons generated. Invalid pipe("Favicon")->design({})..?|;
}

sub _request {
  my ($self, $asset) = @_;

  return {
    favicon_generation => {
      api_key        => $self->api_key,
      favicon_design => $self->design,
      settings       => $self->settings,
      files_location => {type => 'path', path => '/'},
      master_picture => {content => Mojo::Util::b64_encode($asset->content), type => 'inline'}
    }
  };
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::AssetPack::Pipe::Favicon - Generate favicons

=head1 SYNOPSIS

=head2 Application

  plugin AssetPack => {pipes => ["Favicon"]};
  app->asset->pipe("Favicon")->api_key("fd27cc5654345678765434567876545678765556");
  app->asset->process("favicon.ico" => "images/favicon.png");

  # Can also register variations of the favicon:
  app->asset->process("favicon.variant1.ico" => "images/favicon1.png");
  app->asset->process("favicon.variant2.ico" => "images/favicon2.png");

Note that the topic must be either "favicon.ico" or "favicon.some_identifier.ico".

The input image file should be a 260x260 PNG file for optimal results.

=head2 Template

  %= asset "favicon.ico"

The above template will expand to whatever HTML that
L<http://realfavicongenerator.net> has generated, based on L</design>. Example:

  <link rel="icon" type="image/png" href="/asset/52eaz7613a/favicon-16x16.png" sizes="16x16">
  <link rel="icon" type="image/png" href="/asset/65428718f1/favicon-32x32.png" sizes="32x32">
  <link rel="apple-touch-icon" sizes="114x114" href="/asset/9aab8718f1/apple-touch-icon-114x114.png">
  <link rel="apple-touch-icon" sizes="152x152" href="/asset/feee661542/apple-touch-icon-152x152.png">
  <meta name="msapplication-square310x310logo" content="/asset/123ab718f1/largelogo.png">
  <meta name="msapplication-wide310x150logo" content="/asset/a827bfddf0/widelogo.png">

By default this pipe will only create desktop icons. Configure L</design> for
more icons.

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Pipe::Favicon> uses
L<http://realfavicongenerator.net> to generate all the different favicons that
is required for your site.

This pipe is EXPERIMENTAL. Let me know if you are using it.

=head1 ATTRIBUTES

=head2 api_key

  $self = $self->api_key($key);
  $str = $self->api_key;

An API key obtained from L<http://realfavicongenerator.net/api/>.

=head2 design

  $hash = $self->design;
  $self = $self->design({desktop_browser => {}, ios => {}, windows => {}});

Can be used to customize the different designs. Look for "favicon_design" on
L<http://realfavicongenerator.net/api/non_interactive_api> for details.

=head2 settings

  $hash = $self->settings;
  $self = $self->settings({compression => 3});

Can be used to customize the different settings. Look for "settings" on
L<http://realfavicongenerator.net/api/non_interactive_api> for details.

=head1 METHODS

=head2 process

See L<Mojolicious::Plugin::AssetPack::Pipe/process>.

=head1 SEE ALSO

L<http://realfavicongenerator.net>.

L<https://css-tricks.com/favicon-quiz/>.

L<Mojolicious::Plugin::AssetPack>.

=cut
