package Mojolicious::Plugin::AssetPack::Pipe::Favicon;
use Mojo::Base 'Mojolicious::Plugin::AssetPack::Pipe';

use Mojo::DOM;
use Mojo::Util;

# this should be considered private
use constant API_URL => $ENV{MOJO_ASSETPACK_FAVICON_API_URL} || 'https://realfavicongenerator.net/api/favicon';

has api_key  => sub { die 'api_key() must be set' };
has design   => sub { +{desktop_browser => {}} };
has settings => sub { +{error_on_image_too_small => Mojo::JSON->true} };

has _icons => sub { +{} };

sub process {
  my ($self, $assets) = @_;
  return unless $self->topic eq 'favicon.ico';

  my $store = $self->assetpack->store;
  my $asset = $assets->first;
  my $attrs = $asset->TO_JSON;
  my ($db, $files, $markup, @icons);

  $attrs->{key} = join '-', sort keys %{$self->design}
    or die '[AssetPack] Invalid pipe("Favicon")->design({})';

  if ($db = $store->load($attrs)) {
    ($files, $markup) = split /__MARKUP__/, $db->content;
    $files = [grep {/\w/} split /\n/, $files];
  }
  else {
    ($files, $markup) = $self->_fetch($assets);
    $db = join "\n", @$files, __MARKUP__ => $markup;
    $store->save(\$db, $attrs);
  }

  for my $url (@$files) {
    push @icons, $store->asset($url)
      or die "AssetPack was unable to fetch icon asset $url";
  }

  $self->assetpack->{by_checksum}{$_->checksum} = $_ for @icons;
  $self->assetpack->{by_topic}{$self->topic} = Mojo::Collection->new(@icons);

  for my $child (Mojo::DOM->new($markup)->children->each) {
    my $key = $child->{content} ? 'content' : 'href';
    my $icon = shift @icons;
    $self->_icons->{$icon->url} = [$key => $child, $icon];
  }

  if (@icons) {
    my $child
      = Mojo::DOM->new('<link rel="shortcut icon" href="favicon.ico">')->children->first;
    my $icon = shift @icons;
    $self->_icons->{$icon->url} = [href => $child, $icon];
  }
}

sub render {
  my ($self, $c) = @_;
  my $icons = $self->_icons;
  $icons = [map { $icons->{$_} } sort keys %$icons];
  $_->[1]{$_->[0]} = $_->[2]->url_for($c) for @$icons;
  return Mojo::ByteStream->new(join "\n", map { $_->[1] } @$icons);
}

sub _fetch {
  my ($self, $assets) = @_;
  $self->assetpack->ua->inactivity_timeout(60);
  my $res = $self->assetpack->ua->post(API_URL, json => $self->_request($assets))->res;

  unless ($res->code eq '200') {
    my $json = $res->json || {};
    die sprintf '[AssetPack] Could not generate favicon: %s',
      $json->{favicon_generation_result}{result}{error_message} || $res->error->{message};
  }

  my $data   = $res->json->{favicon_generation_result}{favicon};
  my $files  = $data->{files_urls} || [];
  my $markup = $data->{html_code}
    or die qq|[AssetPack] No html_code generated. Invalid pipe("Favicon")->design({})..?|;
  return ($files, $markup) if @$files;
  die qq|[AssetPack] No favicons generated. Invalid pipe("Favicon")->design({})..?|;
}

sub _request {
  my ($self, $assets) = @_;

  return {
    favicon_generation => {
      api_key        => $self->api_key,
      favicon_design => $self->design,
      settings       => $self->settings,
      files_location => {type => 'path', path => '/'},
      master_picture =>
        {content => Mojo::Util::b64_encode($assets->first->content), type => 'inline'}
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

Note that the topic must be "favicon.ico".

The input image file should be 260x260 for optimal results.

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

=head2 render

  $bytestream = $self->render($c);

Used to render the favicons as HTML.

=head1 TODO

Add support for different icons for each platform.

=head1 SEE ALSO

L<http://realfavicongenerator.net>.

L<https://css-tricks.com/favicon-quiz/>.

L<Mojolicious::Plugin::AssetPack>.

=cut
