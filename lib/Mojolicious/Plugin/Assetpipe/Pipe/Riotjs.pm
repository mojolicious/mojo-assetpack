package Mojolicious::Plugin::Assetpipe::Pipe::Riotjs;
use Mojo::Base 'Mojolicious::Plugin::Assetpipe::Pipe';
use Mojolicious::Plugin::Assetpipe::Util qw(diag binpath run $CWD DEBUG);
use File::Basename 'dirname';
use Cwd ();

has node_paths => sub {
  my $self = shift;
  my (@path, %uniq);

  @path = (
    grep { $_ and -d and !$uniq{$_}++ } map { Cwd::abs_path($_) } 'node_modules',
    $self->app->home->rel_dir('node_modules'),
  );

  $self->_make_sure_libraries_exists(\@path);
  return \@path;
};

has _exe => sub {
  return [
    binpath(qw(nodejs node)),
    $ENV{MOJO_ASSETPIPE_RIOTJS_BIN}
      || Cwd::abs_path(File::Spec->catfile(dirname(__FILE__), 'riot.js')),
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
      local $ENV{NODE_PATH} = join ':', @{$self->node_paths};
      run $self->_exe, \$asset->content, \my $js, undef;
      $asset->content($store->save(\$js, $attrs))->FROM_JSON($attrs);
    }
  );
}

sub _make_sure_libraries_exists {
  my ($self, $path) = @_;

  for (@$path) {
    return if -d File::Spec->catdir($_, 'riot');
  }

  local $CWD = $self->app->home->to_string;
  $self->app->log->warn('Installing riot... Please wait. (npm install riot)');
  run [qw(npm install riot)];
  unshift @$path, File::Spec->catdir($CWD, 'node_modules');
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::Assetpipe::Pipe::Riotjs - Process Riotjs .tag files

=head1 SYNOPSIS

  use Mojolicious::Lite;
  plugin assetpipe => {pipes => [qw(Riotjs JavaScript)]};

  app->asset->pipe("Riotjs")->node_paths([...]);

Note that the above will not load the other default pipes, such as
L<Mojolicious::Plugin::Assetpipe::Pipe::Css>.

=head1 DESCRIPTION

L<Mojolicious::Plugin::Assetpipe::Pipe::Riotjs> will process
L<http://riotjs.com/> ".tag" files.

This module require L<https://www.npmjs.com/> to compile Riotjs tag files.

=head1 ATTRIBUTES

=head2 node_paths

  $array_ref = $self->node_paths;
  $self = $self->node_paths(["/path/to/node_modules"]);

An array ref used to set C<NODE_PATH> before running th Riotjs compiler.
The default is "node_modules" in L<Mojo/home>.

=head1 SEE ALSO

L<Mojolicious::Plugin::Assetpipe>.

=cut
