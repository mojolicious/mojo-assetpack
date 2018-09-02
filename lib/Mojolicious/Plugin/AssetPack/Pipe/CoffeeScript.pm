package Mojolicious::Plugin::AssetPack::Pipe::CoffeeScript;
use Mojo::Base 'Mojolicious::Plugin::AssetPack::Pipe';

use Mojolicious::Plugin::AssetPack::Util qw(diag $CWD DEBUG);

sub process {
  my ($self, $assets) = @_;
  my $store = $self->assetpack->store;
  my $file;

  $assets->each(sub {
    my ($asset, $index) = @_;
    return if $asset->format ne 'coffee';
    my $attrs = $asset->TO_JSON;
    @$attrs{qw(format key)} = qw(js coffee);
    return $asset->content($file)->FROM_JSON($attrs) if $file = $store->load($attrs);
    diag 'Process "%s" with checksum %s.', $asset->url, $attrs->{checksum} if DEBUG;
    $self->run([qw(coffee --compile --stdio)], \$asset->content, \my $js);
    $asset->content($store->save(\$js, $attrs))->FROM_JSON($attrs);
  });
}

sub _install_coffee {
  my $self = shift;
  my $path = $self->app->home->rel_file('node_modules/.bin/coffee');
  return $path if -e $path;
  local $CWD = $self->app->home->to_string;
  $self->app->log->warn('Installing coffeescript... Please wait. (npm install coffeescript)');
  $self->run([qw(npm install coffeescript)]);
  return $path;
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::AssetPack::Pipe::CoffeeScript - Process CoffeeScript

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Pipe::CoffeeScript> will process
L<http://coffeescript.org/> files into JavaScript.

This module require the C<coffee> program to be installed. C<coffee> will be
automatically installed using L<https://www.npmjs.com/> unless already
installed.

=head1 METHODS

=head2 process

See L<Mojolicious::Plugin::AssetPack::Pipe/process>.

=head1 SEE ALSO

L<Mojolicious::Plugin::AssetPack>.

=cut
