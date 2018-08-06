package Mojolicious::Plugin::AssetPack::Pipe::Favicon;
use Mojo::Base 'Mojolicious::Plugin::AssetPack::Pipe';

use Mojo::DOM;
use Mojo::JSON qw(false true);
use Mojo::Template;
use Mojo::Util;
use Mojolicious::Plugin::AssetPack::Util qw(checksum croak);
use Mojolicious::Plugin::JSONConfig;

# this should be considered private
use constant API_URL => $ENV{MOJO_ASSETPACK_FAVICON_API_URL} || 'https://realfavicongenerator.net/api/favicon';

my $TOPIC_RE    = qr!^favicon(\.\w+)?\.ico$!;
my $JSON_PARSER = Mojolicious::Plugin::JSONConfig->new;

has api_key => sub { croak 'api_key() must be set' };
has settings => sub { +{error_on_image_too_small => true} };

sub before_process {
  my ($self, $assets) = @_;
  return unless $self->topic =~ $TOPIC_RE;

  # Load the config file
  my @sorted;
  push @sorted, grep { $_->url =~ /\.json$/ } @$assets;
  croak 'Need a .json file in assets list.' unless $sorted[0];
  $sorted[0]
    ->content(Mojo::JSON::encode_json($JSON_PARSER->parse($sorted[0]->content, $sorted[0]->path, {}, $self->app)));

  # Figure out where the icon is stored
  push @sorted, grep { $_ ne $sorted[0] } @$assets;
  $sorted[0]->checksum(checksum(join ':', map { $_->checksum } @sorted));
  @$assets = @sorted;
}

sub process {
  my ($self, $assets) = @_;
  return unless $self->topic =~ $TOPIC_RE;

  my ($settings, $icon) = @$assets;
  my $attrs = $settings->TO_JSON(format => 'txt', key => 'favicon');
  my ($json, %sub_assets);

  if ($self->store->load($settings, $attrs)) {
    $json = Mojo::JSON::decode_json($settings->content);
  }
  else {
    $self->app->log->info(qq(Generating assets for "@{[$self->topic]}". Please wait...));
    $json = $self->_fetch_assets($settings, $icon);
    $self->store->save($settings, \Mojo::JSON::encode_json($json), $attrs);
  }

  my $renderer = sub {
    my ($asset, $c, $args, @attrs) = @_;
    my $content = $asset->content;
    $content =~ s!"(/asset/)([^.]+\.\w{3,})"!sprintf '"%s"', $sub_assets{$2} ? $sub_assets{$2}->url_for($c) : "$1$2"!ge;
    return $content if $args;
    return $c->render(data => $content);
  };

  for my $url (@{$json->{favicon_generation_result}{favicon}{files_urls}}) {
    my $asset = $self->store->asset($url) or croak 'Unable to fetch favicon data from "%s".', $url;
    $sub_assets{join '.', $asset->name, $asset->format} = $asset;
    $asset->renderer($renderer) if $asset->format =~ m!(manifest|xml|webapp)$!;
    $self->assetpack->{by_checksum}{$asset->checksum} = $asset;
  }

  my $markup = $json->{favicon_generation_result}{favicon}{html_code};
  unless ($markup =~ m!msapplication-config! and $settings->content =~ m!"windows"!) {
    $markup =~ s![\r\n]+$!!;
    $markup .= qq(\n<meta name="msapplication-config" content="/asset/browserconfig.xml">);
  }

  $settings->content($markup)->tag_for($renderer);
}

sub _fetch_assets {
  my ($self, $settings, $icon) = @_;
  my $tx = $self->assetpack->ua->post(API_URL,
    json => $self->_normalize_request(Mojo::JSON::decode_json($settings->content), $icon));

  return $tx->res->json if $tx->success;
  my $json = $tx->res->json || {};
  croak 'Could not generate favicon: %s',
    $json->{favicon_generation_result}{result}{error_message} || $tx->error->{message};
}

sub _normalize_request {
  my ($self, $json, $icon) = @_;

  $json = {favicon_generation => $json} unless $json->{favicon_generation};
  $json->{favicon_generation} = {favicon_design => $json->{favicon_generation}}
    unless $json->{favicon_generation}{favicon_design};
  $json->{favicon_generation}{api_key} ||= $self->api_key;
  $json->{favicon_generation}{files_location} = {type => 'path', path => '/asset'};
  $json->{favicon_generation}{master_picture} = {content => Mojo::Util::b64_encode($icon->content), type => 'inline'};
  $json->{favicon_generation}{settings} ||= $self->settings;
  $json->{favicon_generation}{versioning} = false;

  if (my $defaults = delete $json->{favicon_generation}{favicon_design}{defaults}) {
    if (my $section = $json->{favicon_generation}{favicon_design}{android_chrome}) {
      $section->{manifest}{display}     ||= 'standalone';
      $section->{manifest}{name}        ||= $defaults->{app_name};
      $section->{manifest}{theme_color} ||= $defaults->{theme_color};
      $section->{picture_aspect}        ||= 'shadow';
    }
    if (my $section = $json->{favicon_generation}{favicon_design}{firefox_app}) {
      $section->{background_color}          ||= $defaults->{background_color};
      $section->{manifest}{app_description} ||= $defaults->{description};
      $section->{manifest}{app_name}        ||= $defaults->{app_name};
      $section->{manifest}{developer_name}  ||= $defaults->{developer_name};
      $section->{manifest}{developer_url}   ||= $defaults->{developer_url};
      $section->{picture_aspect}            ||= 'circle';
      $section->{circle_inner_margin}       ||= 5 if $section->{picture_aspect} eq 'circle';
      $section->{keep_picture_in_circle}    ||= true if $section->{picture_aspect} eq 'circle';
    }
    if (my $section = $json->{favicon_generation}{favicon_design}{ios}) {
      $section->{app_name}         ||= $defaults->{app_name};
      $section->{background_color} ||= $defaults->{background_color};
      $section->{picture_aspect}   ||= 'background_and_margin';
      $section->{margin}           ||= 4 if $section->{picture_aspect} eq 'background_and_margin';
    }
    if (my $section = $json->{favicon_generation}{favicon_design}{safari_pinned_tab}) {
      $section->{picture_aspect} ||= 'black_and_white';
      $section->{theme_color} ||= $defaults->{theme_color};
    }
    if (my $section = $json->{favicon_generation}{favicon_design}{windows}) {
      $section->{app_name}         ||= $defaults->{app_name};
      $section->{background_color} ||= $defaults->{background_color};
      $section->{picture_aspect}   ||= 'white_silhouette';
      $section->{assets}           ||= {
        windows_80_ie_10_tile       => true,
        windows_10_ie_11_edge_tiles => {big => true, medium => true, rectangle => false, small => false},
      };
    }
  }

  return $json;
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::AssetPack::Pipe::Favicon - Generate favicons

=head1 SYNOPSIS

=head2 Application

  plugin AssetPack => {pipes => ["Favicon"]};
  app->asset->pipe("Favicon")->api_key("fd27cc5654345678765434567876545678765556");
  app->asset->process("favicon.ico" => "images/realfavicongenerator.json", "images/favicon.png");

  # Can also register variations of the favicon:
  app->asset->process("favicon.variant1.ico" => "images/favicon1.json", "images/favicon1.png");
  app->asset->process("favicon.variant2.ico" => "images/favicon2.json", "images/favicon2.png");

Note that the topic must be either "favicon.ico" or
"favicon.some_variant.ico". The JSON asset must contain the request that is
sent to L<https://realfavicongenerator.net/>. See L</Design file> for more details.

The input image file should be a 260x260 PNG file for optimal results.

=head2 Design file

The input design file must be in a format that is supported by
L<Mojolicious::Plugin::JSONConfig>, and follow the structure described on
L<https://realfavicongenerator.net/api/non_interactive_api> or one of the
three variants below:

  {"favicon_generation":{"favicon_design":{"desktop_browser":{}}}}
  {"favicon_design":{"desktop_browser":{}}}
  {"desktop_browser":{}}

Some of the top level keys are not required or have special handling by this
pipe:

=over 2

=item * "api_key"

"api_key" defaults to the value from the L</api_key> attribute.

=item * "favicon_design"

You need to specify your own design. If you like, you can specify the design
on the top level of the design file. A special "defaults" section is
supported, which will set default values for other design sections. Here are
the supported values:

  {
    "defaults": {
      "app_name": "My sample app",
      "background_color": "#456789",
      "description": "Yet another sample application",
      "developer_name": "Philippe Bernard",
      "developer_url": "http://stackoverflow.com/users/499917/philippe-b",
      "theme_color": "#4972ab"
    }
  }

Please see the source code for how default values are used.

=item * "files_location"

"files_location" will be set by this pipe.

=item * "master_picture"

"master_picture" will be set to the icon file passed into this pipe. See
L</SYNOPSIS> for examples.

=item * "settings"

"settings" defaults to the value from the L</settings> attribute.

=item * "versioning"

"versioning" will be set to "false" by this pipe.

=back

=head2 Template

  %= asset "favicon.ico"

The above template will expand to whatever HTML that
L<http://realfavicongenerator.net> has generated. Below is an example:

  <link rel="icon" type="image/png" href="/asset/52eaz7613a/favicon-16x16.png" sizes="16x16">
  <link rel="icon" type="image/png" href="/asset/65428718f1/favicon-32x32.png" sizes="32x32">
  <link rel="apple-touch-icon" sizes="114x114" href="/asset/9aab8718f1/apple-touch-icon-114x114.png">
  <link rel="apple-touch-icon" sizes="152x152" href="/asset/feee661542/apple-touch-icon-152x152.png">
  <meta name="msapplication-square310x310logo" content="/asset/123ab718f1/largelogo.png">
  <meta name="msapplication-wide310x150logo" content="/asset/a827bfddf0/widelogo.png">

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

=head2 settings

  $hash = $self->settings;
  $self = $self->settings({compression => 3});

Can be used to customize the different settings. Look for "settings" on
L<http://realfavicongenerator.net/api/non_interactive_api> for details.

=head1 METHODS

=head2 before_process

See L<Mojolicious::Plugin::AssetPack::Pipe/before_process>.

=head2 process

See L<Mojolicious::Plugin::AssetPack::Pipe/process>.

=head1 SEE ALSO

L<http://realfavicongenerator.net>.

L<https://css-tricks.com/favicon-quiz/>.

L<Mojolicious::Plugin::AssetPack>.

=cut
