package Mojolicious::Plugin::AssetPack::Asset;
use Mojo::Base -base;
use Mojo::Asset::Memory;
use Mojolicious::Plugin::AssetPack::Util qw(diag has_ro DEBUG);

has checksum => sub { Mojolicious::Plugin::AssetPack::Util::checksum(shift->content) };
has format   => sub { shift->url =~ /\.(\w+)$/ ? lc $1 : '' };
has minified => sub { shift->url =~ /\bmin\b/ ? 1 : 0 };
has mtime    => sub { shift->_asset->mtime };

has _asset => sub {
  my $self = shift;
  return $self->content(delete $self->{content})->_asset if $self->{content};
  return Mojo::Asset::File->new(path => delete $self->{path}) if $self->{path};
  return Mojo::Asset::Memory->new;
};

has_ro 'name' => sub { local $_ = (split m!(\\|/)!, $_[0]->url)[-1]; s!\.\w+$!!; $_ };
has_ro 'url';

sub content {
  my $self = shift;
  return $self->_asset->slurp unless @_;
  return $self->_asset($_[0]->_asset) if UNIVERSAL::isa($_[0], __PACKAGE__);
  return $self->_asset($_[0])         if UNIVERSAL::isa($_[0], 'Mojo::Asset');
  return $self->_asset(Mojo::Asset::Memory->new->add_chunk($_[0]));
}

sub get_chunk { shift->_asset->get_chunk(@_) }

sub path { $_[0]->_asset->isa('Mojo::Asset::File') ? $_[0]->_asset->path : '' }
sub size { $_[0]->_asset->size }

sub FROM_JSON {
  my ($self, $attrs) = @_;
  $self->$_($attrs->{$_})
    for grep { defined $attrs->{$_} } qw(checksum format minified mtime);
  $self;
}

sub TO_JSON {
  return {map { ($_ => $_[0]->$_) } qw(checksum format minified name mtime url)};
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::AssetPack::Asset - An asset

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Asset> represents an asset.

=head1 SYNOPSIS

  use Mojolicious::Plugin::AssetPack::Asset;
  my $asset = Mojolicious::Plugin::AssetPack::Asset->new(url => "...");

=head1 ATTRIBUTES

=head2 checksum

  $str = $self->checksum;
  $self = $self->checksum($str);

The L<checksum|Mojolicious::Plugin::AssetPack::Util/checksum> of L</content>.

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
  $self = $self->content(Mojo::Asset::Memory->new);

Used to get or set the content of this asset. The default will be built from
passing L</url> to L<Mojolicious::Plugin::AssetPack::Store/file>.

=head2 get_chunk

See L<Mojo::Asset/get_chunk>.

=head2 path

  $str = $self->path;

Returns the path to the asset, if it exists on disk.

=head2 size

See L<Mojo::Asset/size>.

=head2 FROM_JSON

  $self = $self->FROM_JSON($hash_ref);

The opposite of L</TO_JSON>. Will set the read/write L</ATTRIBUTES> from the
values in C<$hash_ref>.

=head2 TO_JSON

  $hash_ref = $self->FROM_JSON;

The opposite of L</FROM_JSON>. Will generate a hash ref from L</ATTRIBUTES>.

=head1 SEE ALSO

L<Mojolicious::Plugin::AssetPack>.

=cut
