package Mojolicious::Plugin::Assetpipe::Pipe::Riotjs;
use Mojo::Base 'Mojolicious::Plugin::Assetpipe::Pipe';
use Mojolicious::Plugin::Assetpipe::Util qw(diag $CWD DEBUG);
use File::Basename 'dirname';
use Cwd ();

has _riotjs => sub {
  my $self = shift;

  return [
    $self->_find_app('nodejs') || $self->_find_app('node'),
    Cwd::abs_path(File::Spec->catfile(dirname(__FILE__), 'riot.js')),
  ];
};

sub _install_riot {
  my $self = shift;
  my $path = $self->app->home->rel_file('node_modules/.bin/riot');
  return $path if -e $path;
  local $CWD = $self->app->home->to_string;
  $self->app->log->warn('Installing riot... Please wait. (npm install riot)');
  $self->run([qw(npm install riot)]);
  return $path;
}

sub _process {
  my ($self, $assets) = @_;
  my $store = $self->assetpipe->store;
  my $file;

  $assets->each(
    sub {
      my ($asset, $index) = @_;
      my $attrs = $asset->TO_JSON;
      $attrs->{key}    = 'riot';
      $attrs->{format} = 'js';
      return unless $asset->format eq 'tag';
      return $asset->content($file)->FROM_JSON($attrs) if $file = $store->load($attrs);
      local $CWD = $self->app->home->to_string;
      local $ENV{NODE_PATH} = $self->app->home->rel_dir('node_modules');
      $self->run([qw(riot --version)], undef, \undef) unless $self->{installed}++;
      $self->run($self->_riotjs, \$asset->content, \my $js);
      $asset->content($store->save(\$js, $attrs))->FROM_JSON($attrs);
    }
  );
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::Assetpipe::Pipe::Riotjs - Process Riotjs .tag files

=head1 SYNOPSIS

  use Mojolicious::Lite;
  plugin assetpipe => {pipes => [qw(Riotjs JavaScript)]};

Note that the above will not load the other default pipes, such as
L<Mojolicious::Plugin::Assetpipe::Pipe::Css>.

=head1 DESCRIPTION

L<Mojolicious::Plugin::Assetpipe::Pipe::Riotjs> will process
L<http://riotjs.com/> ".tag" files.

This module require L<https://www.npmjs.com/> to compile Riotjs tag files.

=head1 SEE ALSO

L<Mojolicious::Plugin::Assetpipe>.

=cut
