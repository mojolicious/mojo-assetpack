package Mojolicious::Plugin::AssetPack::Pipe::Riotjs;
use Mojo::Base 'Mojolicious::Plugin::AssetPack::Pipe';

use Mojo::File 'path';
use Mojolicious::Plugin::AssetPack::Util qw(diag $CWD DEBUG);

has _riotjs => sub { [shift->_find_app([qw(nodejs node)]), path(__FILE__)->dirname->child('riot.js')] };

sub process {
  my ($self, $assets) = @_;
  my $store = $self->assetpack->store;
  my $file;

  $assets->each(sub {
    my ($asset, $index) = @_;
    my $attrs = $asset->TO_JSON;
    $attrs->{key}    = 'riot';
    $attrs->{format} = 'js';
    return unless $asset->format eq 'tag';
    return $asset->content($file)->FROM_JSON($attrs) if $file = $store->load($attrs);
    local $CWD = $self->app->home->to_string;
    local $ENV{NODE_PATH} = $self->app->home->rel_file('node_modules');
    $self->run([qw(riot --version)], undef, \undef) unless $self->{installed}++;
    $self->run($self->_riotjs, \$asset->content, \my $js);
    $asset->content($store->save(\$js, $attrs))->FROM_JSON($attrs);
  });
}

sub _install_riot {
  my $self = shift;
  my $path = $self->app->home->rel_file('node_modules/.bin/riot');
  return $path if -e $path;
  local $CWD = $self->app->home->to_string;
  $self->app->log->warn('Installing riot... Please wait. (npm install riot)');
  $self->run([qw(npm install riot)]);
  return $path;
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::AssetPack::Pipe::Riotjs - Process Riotjs .tag files

=head1 SYNOPSIS

  use Mojolicious::Lite;
  plugin AssetPack => {pipes => [qw(Riotjs JavaScript)]};

Note that the above will not load the other default pipes, such as
L<Mojolicious::Plugin::AssetPack::Pipe::Css>.

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Pipe::Riotjs> will process
L<http://riotjs.com/> ".tag" files.

This module require L<https://www.npmjs.com/> to compile Riotjs tag files.

=head1 METHODS

=head2 process

See L<Mojolicious::Plugin::AssetPack::Pipe/process>.

=head1 SEE ALSO

L<Mojolicious::Plugin::AssetPack>.

=cut
