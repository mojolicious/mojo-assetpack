package Mojolicious::Plugin::AssetPack::Pipe::Fetch;
use Mojo::Base 'Mojolicious::Plugin::AssetPack::Pipe';

use Mojolicious::Plugin::AssetPack::Util qw(diag DEBUG);
use Mojo::URL;

# Only made public for quick fixes. Subject for change
our %FORMATS = (
  css => {
    re  => qr{url\((['"]{0,1})(.*?)\1\)},
    pos => sub {
      my ($start, $url, $quotes) = @_;
      my $len = length $url;
      return $start - length($quotes) - $len - 1, $len;
    },
  },
  js => {
    re  => qr{(//\W*sourceMappingURL=)(\S+)}m,
    pos => sub {
      my ($start, $url) = @_;
      my $len = length $url;
      return $start - $len, $len;
    },
  },
);

sub process {
  my ($self, $assets) = @_;
  my $store = $self->assetpack->store;
  my $route = $self->assetpack->route;
  my %related;

  return $assets->each(sub {
    my ($asset, $index) = @_;
    return unless $asset->url =~ /^https?:/;
    return unless my $format = $FORMATS{$asset->format};

    my $base    = Mojo::URL->new($asset->url);
    my $content = $asset->content;
    my $re      = $format->{re};

    while ($content =~ /$re/g) {
      my @matches = ($2, $1);
      my $url = $matches[0];

      next if $url =~ /^(?:\#|data:)/;    # Avoid "data:image/svg+xml..." and "#foo"

      $url = Mojo::URL->new($url);
      $url = $url->base($base)->to_abs->fragment(undef) unless $url->is_abs;

      unless ($related{$url}) {
        diag "Fetch resource $url" if DEBUG;
        my $related = $store->asset($url) or die "AssetPack was unable to fetch related asset $url";
        $self->assetpack->process($related->name, $related);
        my $path = $route->render($related->TO_JSON);
        $path =~ s!^/!!;
        my $up = join '', map {'../'} $path =~ m!\/!g;
        $related{$url} = "$up$path";
      }

      my ($start, $len) = $format->{pos}->(pos($content), @matches);
      substr $content, $start, $len, Mojo::URL->new($related{$url})->query(Mojo::Parameters->new);
      pos($content) = $start + $len;
    }

    $asset->content($content);
  });
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::AssetPack::Pipe::Fetch - Fetch related assets

=head1 SYNOPSIS

  use Mojolicious::Lite;
  plugin AssetPack => {pipes => [qw(Css Fetch)]};
  app->asset->process(
    "app.css" =>
      "https://maxcdn.bootstrapcdn.com/font-awesome/4.5.0/css/font-awesome.min.css"
  );

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Pipe::Fetch> will look for "url()" in a CSS
file and fetch the resource from the remote location.

Note that this pipe is EXPERIMENTAL and subject for change.

=head1 METHODS

=head2 process

See L<Mojolicious::Plugin::AssetPack::Pipe/process>.

=head1 SEE ALSO

L<Mojolicious::Plugin::AssetPack>.

=cut
