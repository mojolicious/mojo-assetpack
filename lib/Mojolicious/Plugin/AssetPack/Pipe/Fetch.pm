package Mojolicious::Plugin::AssetPack::Pipe::Fetch;
use Mojo::Base 'Mojolicious::Plugin::AssetPack::Pipe';
use Mojolicious::Plugin::AssetPack::Util qw(diag DEBUG);
use Mojo::URL;

our %formats = (
    css => {
        regex => qr{url\((['"]{0,1})(.*?)\1\)},
        subst => sub {
            my ($content, $start, $len_pre, $len_url, $with) = @_;
            substr $content, $start, $len_url,
                Mojo::URL->new($with)->query(Mojo::Parameters->new);
            return $content;
        }
    },
    js => {
        regex => qr{(\/\/\# sourceMappingURL=)(.*?)$},
        subst => sub {
            my ($content, $start, $len_pre, $len_url, $with) = @_;
            substr $content, $start, $len_pre + $len_url,
                "//# sourceMappingURL=$with";
            return $content;
        }
    }
);

sub process {
  my ($self, $assets) = @_;
  my $store = $self->assetpack->store;
  my $route = $self->assetpack->route;
  my %related;

  return $assets->each(
    sub {
      my ($asset, $index) = @_;
      return unless exists $formats{$asset->format} &&
        exists $formats{$asset->format}->{regex} &&
        exists $formats{$asset->format}->{subst}; 
      return unless $asset->url =~ /^https?:/;

      my $base    = Mojo::URL->new($asset->url);
      my $content = $asset->content;
      my $regex = $formats{$asset->format}->{regex};

      while ($content =~ /$regex/g) {
        my ($pre, $url) = ($1, $2);
        my $len_pre   = length $pre;
        my $len_url   = length $url;
        my $start = pos($content) - $len_pre - $len_url;

        next if $url =~ /^(?:\#|data:)/;    # Avoid "data:image/svg+xml..." and "#foo"

        $url = Mojo::URL->new($url);
        $url = $url->base($base)->to_abs->fragment(undef) unless $url->is_abs;

        unless ($related{$url}) {
          diag "Fetch resource $url" if DEBUG;
          my $related = $store->asset($url)
            or die "AssetPack was unable to fetch related asset $url";
          $self->assetpack->process($related->name, $related);
          my $path = $route->render($related->TO_JSON);
          $path =~ s!^/!!;
          my $up = join '', map {'../'} $path =~ m!\/!g;
          $related{$url} = "$up$path";
        }

        $content = $formats{$asset->format}->{subst}->(
            $content, $start, $len_pre, $len_url, $related{$url}
        );

        pos($content) = $start + $len_url;
      }

      $asset->content($content);
    }
  );
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
