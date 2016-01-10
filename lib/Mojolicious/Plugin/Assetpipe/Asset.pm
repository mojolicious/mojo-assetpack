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

sub new {
  my $self = shift->SUPER::new(@_);
  Scalar::Util::weaken($self->{assetpipe});
  $self;
}

sub size { shift->_asset->size }

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::Assetpipe::Asset - An asset

=head1 DESCRIPTION

L<Mojolicious::Plugin::Assetpipe::Asset> represents an asset.

=head1 SYNOPSIS

  use Mojolicious::Plugin::Assetpipe::Asset;
  my $asset = Mojolicious::Plugin::Assetpipe::Asset->new(
                assetpipe => Mojolicious::Plugin::Assetpipe->new,
                url       => "...",
              );

=head1 ATTRIBUTES

=head2 assetpipe

  $obj = $self->assetpipe;

Holds a L<Mojolicious::Plugin::Assetpipe> object.

=head2 checksum

  $str = $self->checksum;
  $self = $self->checksum($str);

The L<checksum|Mojolicious::Plugin::Assetpipe::Util/checksum> of L</content>.

=head2 format

  $str = $self->format;
  $self = $self->format($str);

The format of L</content>. Defaults to the extension of L</url> or empty string.

=head2 minified

  $bool = $self->minified;
  $self = $self->minified($bool);

Will be set to true if either L</url> contains "min" or if a pipe has
minified L</content>.

=head2 mtime

  $epoch = $self->mtime;
  $self = $self->mtime($epoch);

Holds the modification time of L</content>.

=head2 name

  $str = $self->name;

Returns the last part of l</url> without extension.

=head2 url

  $str = $self->url;

Returns the location of the asset.

=head1 METHODS

=head2 content

  $bytes = $self->content;
  $self = $self->content($bytes);

Used to get or set the content of this asset.

=head2 get_chunk

See L<Mojo::Asset/get_chunk>.

=head2 new

Object constructor. Makes sure L</assetpipe> is weaken.

=head2 size

See L<Mojo::Asset/size>.

=head1 SEE ALSO

L<Mojolicious::Plugin::Assetpipe>.

=cut
