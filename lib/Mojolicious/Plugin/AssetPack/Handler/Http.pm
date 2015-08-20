package Mojolicious::Plugin::AssetPack::Handler::Http;

=head1 NAME

Mojolicious::Plugin::AssetPack::Handler::Http - A URL handler for http:// assets

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Handler::Sprites> is a module that can
fetch assets from web.

This class is EXPERIMENTAL.

=cut

use Mojo::Base -base;
use Mojolicious::Types;
use Mojolicious::Plugin::AssetPack::Asset;
use constant DEBUG => $ENV{MOJO_ASSETPACK_DEBUG} || 0;

=head1 ATTRIBUTES

=head2 asset_for

  $asset = $self->asset_for($url, $assetpack);

This method tries to download the asset from web.

=cut

sub asset_for {
  my ($self, $url, $assetpack) = @_;
  my $lookup = Mojolicious::Plugin::AssetPack::_name($url);

  if (my $asset = $assetpack->_find('packed', qr{^$lookup\.\w+$})) {
    $assetpack->_app->log->debug("Asset $url is fetched") if DEBUG == 2;
    return $asset;
  }

  my $tx  = $assetpack->_ua->get($url);
  my $ct  = $tx->res->headers->content_type // 'text/plain';
  my $ext = Mojolicious::Types->new->detect($ct) || 'txt';

  if (my $e = $tx->error) {
    die "Asset $url could not be fetched: $e->{message}";
  }

  $ext = $ext->[0] if ref $ext;
  $ext = $tx->req->url->path =~ m!\.(\w+)$! ? $1 : 'txt' if !$ext or $ext eq 'bin';
  $assetpack->_app->log->info("Asset $url was fetched successfully");
  $assetpack->_asset("$lookup.$ext")->content($tx->res->body);
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
