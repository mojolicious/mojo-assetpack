package Mojolicious::Plugin::AssetPack::Pipe::TypeScript;
use Mojo::Base 'Mojolicious::Plugin::AssetPack::Pipe';

use Mojo::File 'path';
use Mojolicious::Plugin::AssetPack::Util qw(diag $CWD DEBUG);

has _typescript => sub {
  my $self = shift;

  return [$self->_find_app([qw(nodejs node)]), path(__FILE__)->dirname->child('typescript.js')->to_abs,];
};

sub process {
  my ($self, $assets) = @_;
  my $store = $self->assetpack->store;
  my $file;

  $assets->each(sub {
    my ($asset, $index) = @_;
    my $attrs = $asset->TO_JSON;
    $attrs->{key}    = 'ts';
    $attrs->{format} = 'js';
    return unless $asset->format eq 'ts';
    return $asset->content($file)->FROM_JSON($attrs) if $file = $store->load($attrs);

    $self->_install_typescript unless $self->{installed}++;
    local $CWD = $self->app->home->to_string;
    local $ENV{NODE_PATH} = $self->app->home->rel_file('node_modules');

    $self->run($self->_typescript, \$asset->content, \my $js);
    $asset->content($store->save(\$js, $attrs))->FROM_JSON($attrs);
  });
}

sub _install_typescript {
  my $self = shift;

  # TODO: This is a bit fragile, since tsc is not part of typescript-simple
  my $path = $self->app->home->rel_file('node_modules/.bin/tsc');
  return 1 if -e $path;

  local $CWD = $self->app->home->to_string;
  $self->app->log->warn('Installing typescript-simple... Please wait. (npm install typescript-simple)');
  $self->run([qw(npm install typescript-simple)]);
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::AssetPack::Pipe::TypeScript - Process TypeScript .ts files

=head1 SYNOPSIS

  $app->plugin(pipes => [qw(TypeScript JavaScript Combine)]);
  $app->asset->process("app.js" => qw(foo.ts));

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Pipe::TypeScript> will process
L<https://www.typescriptlang.org/> files into JavaScript.

This module require the C<typescript-simple> nodejs library to be installed.
C<typescript-simple> will be automatically installed using
L<https://www.npmjs.com/> unless already installed.

=head1 METHODS

=head2 process

See L<Mojolicious::Plugin::AssetPack::Pipe/process>.

=head1 SEE ALSO

L<Mojolicious::Plugin::AssetPack>.

=cut
