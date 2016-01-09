package Mojolicious::Plugin::Assetpipe::Asset;
use Mojo::Base -base;
use Mojo::Asset::Memory;
use Mojolicious::Plugin::Assetpipe::Util 'has_ro';

has checksum => sub { Mojolicious::Plugin::Assetpipe::Util::checksum(shift->content) };
has format   => sub { shift->url =~ /\.(\w+)$/ ? lc $1 : '' };
has minified => sub { shift->url =~ /\bmin\b/ ? 1 : 0 };
has mtime    => sub { shift->_asset->mtime };

has_ro 'assetpipe';
has_ro name => sub { local $_ = (split m!(\\|/)!, $_[0]->url)[-1]; s!\.\w+$!!; $_ };
has_ro 'url';

has _asset => sub {
  my $self = shift;
  return $self->assetpipe->static->file($self->url)
    || die die qq(Cannot find asset for "@{[$self->url]}".);
};

sub content {
  my $self = shift;
  return $self->_asset(Mojo::Asset::Memory->new->add_chunk($_[0])) if @_;
  return $self->_asset->slurp;
}

sub get_chunk { shift->_asset->get_chunk(@_) }
sub is_file   { shift->_asset->isa('Mojo::Asset::File') }
sub size      { shift->_asset->size }

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
