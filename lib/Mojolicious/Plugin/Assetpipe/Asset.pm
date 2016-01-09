package Mojolicious::Plugin::Assetpipe::Asset;
use Mojo::Base -base;
use Mojo::Util;
use Mojolicious::Plugin::Assetpipe::Util 'has_ro';

has assetpipe => sub { };
has checksum  => sub { Mojolicious::Plugin::Assetpipe::Util::checksum(shift->slurp) };
has format    => sub { shift->url =~ /\.(\w+)$/ ? lc $1 : '' };

has_ro name => sub { local $_ = (split m!(\\|/)!, $_[0]->url)[-1]; s!\.\w+$!!; $_ };
has_ro 'url';

sub slurp {
  my $self = shift;
  my $url  = $self->url;
  $url =~ s!^/!!;
  my $file = $self->assetpipe->static->file($url)
    or die die qq(Cannot find asset for "@{[$self->url]}".);
  return $file->slurp;
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::Assetpipe::Asset - Description

=head1 SYNOPSIS

  use Mojolicious::Plugin::Assetpipe::Asset;
  my $obj = Mojolicious::Plugin::Assetpipe::Asset->new;

=head1 DESCRIPTION

L<Mojolicious::Plugin::Assetpipe::Asset> is a ...

=head1 ATTRIBUTES

=head1 METHODS

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut
