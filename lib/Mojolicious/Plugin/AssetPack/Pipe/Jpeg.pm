package Mojolicious::Plugin::AssetPack::Pipe::Jpeg;
use Mojo::Base 'Mojolicious::Plugin::AssetPack::Pipe';

use Mojolicious::Plugin::AssetPack::Util qw(diag DEBUG);

has app      => 'jpegoptim';
has app_args => sub {
  my $self = shift;
  return [DEBUG ? ('-v') : ('-q'), qw(-f --stdin --stdout)] if $self->app eq 'jpegoptim';
  return [];
};

sub process {
  my ($self, $assets) = @_;
  my $store = $self->assetpack->store;
  my $file;

  return $assets->each(sub {
    my ($asset, $index) = @_;
    my $attrs = $asset->TO_JSON;
    $attrs->{key} = sprintf '%s-min', $self->app;
    $attrs->{minified} = 1;
    return if $asset->format !~ /^jpe?g$/ or $asset->minified;
    return unless $self->assetpack->minify;
    return $asset->content($file)->minified(1) if $file = $store->load($attrs);
    diag 'Process "%s", with checksum %s.', $asset->url, $attrs->{checksum} if DEBUG;
    $asset->content($store->save($self->_run_app($asset), $attrs))->FROM_JSON($attrs);
  });
}

sub _install_jpegoptim {
  my $self  = shift;
  my $class = ref $self;
  die "$class requires https://github.com/tjko/jpegoptim";
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::AssetPack::Pipe::Jpeg - Crush JPEG image files

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Pipe::Jpeg> can be used to crush "jpeg" image
files.

This pipe is EXPERIMENTAL. Feedback wanted.

=head1 ATTRIBUTES

=head2 app

  $str = $self->app;
  $self = $self->app("jpegoptim");

Can be used to set a custom application instead of "jpegoptim".

=head2 app_args

  $array = $self->app_args;
  $self = $self->app_args([qw(-f --stdin --stdout)]);

Can be used to set custom L</app> arguments. The special C<$input> string in
the argument list will be replaced with the path to a temp file holding the
image data.

If no C<$input> element is found in the L</app_args> list, then STDIN and
STDOUT will be used instead.

=head1 METHODS

=head2 process

See L<Mojolicious::Plugin::AssetPack::Pipe/process>.

=head1 SEE ALSO

L<Mojolicious::Plugin::AssetPack>.

=cut
