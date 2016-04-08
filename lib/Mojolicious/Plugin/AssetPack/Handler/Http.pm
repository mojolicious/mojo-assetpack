package Mojolicious::Plugin::AssetPack::Handler::Http;
use Mojo::Base -base;
use Mojolicious::Types;
use Mojolicious::Plugin::AssetPack::Asset;
use constant DEBUG => $ENV{MOJO_ASSETPACK_DEBUG} || 0;

sub asset_for {
  my ($self, $url, $assetpack) = @_;
  my $name = do { local $_ = "$url"; s![^\w-]!_!g; $_ };
  my ($asset, $e, $tx, $ext);

  # already downloaded
  return $asset if $asset = $assetpack->_packed(qr{^$name\.\w+$});

  $tx = $assetpack->ua->get($url);
  $ext = Mojolicious::Types->new->detect($tx->res->headers->content_type // 'text/plain');
  die "Asset $url could not be fetched: $e->{message}" if $e = $tx->error;

  $ext = $ext->[0] if ref $ext;
  $ext = $tx->req->url->path =~ m!\.(\w+)$! ? $1 : 'txt' if !$ext or $ext eq 'bin';
  $assetpack->_app->log->info("Asset $url was saved as $name.$ext");
  $assetpack->_asset("$name.$ext")->spurt($tx->res->body);
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::AssetPack::Handler::Http - DEPRECATED

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Handler::Http> will be DEPRECATED.

=head1 ATTRIBUTES

=head2 asset_for

=head1 SEE ALSO

L<Mojolicious::Plugin::AssetPack>.

=cut
