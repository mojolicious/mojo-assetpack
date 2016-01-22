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

sub _process {
  my ($self, $assets) = @_;
  my $store = $self->assetpipe->store;
  my $file;

  $assets->each(
    sub {
      my ($asset, $index) = @_;
      my $attr = $asset->TO_JSON;
      $attr->{minified} = $self->assetpipe->minify;
      $attr->{format}   = 'js';
      return unless $asset->format eq 'tag';
      return $asset->content($file)->FROM_JSON($attr) if $file = $store->load($attr);
      local $ENV{NODE_PATH} = join ':', @{$self->node_paths};
      run $self->_exe, \$asset->content, \my $js, undef;
      delete $attr->{minified};    # not yet minifed
      $asset->content($store->save(\$js, $attr))->FROM_JSON($attr);
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

=head1 DESCRIPTION

L<Mojolicious::Plugin::Assetpipe::Pipe::Riotjs> will process
L<http://riotjs.com/> ".tag" files.

This module require L<https://www.npmjs.com/> to compile Riotjs tag files.

=head1 ATTRIBUTES

=head2 node_paths

  $array_ref = $self->node_paths;
  $self = $self->node_paths(["/path/to/node_modules"]);

An array ref used to set C<NODE_PATH> before running th Riotjs compiler.

=head1 SEE ALSO

L<Mojolicious::Plugin::Assetpipe>.

=cut
