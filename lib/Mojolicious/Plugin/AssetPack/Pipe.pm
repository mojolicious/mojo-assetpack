package Mojolicious::Plugin::AssetPack::Pipe;
use Mojo::Base -base;

use File::Temp ();
use IPC::Run3  ();
use List::Util 'first';
use Mojo::File 'path';
use Mojo::JSON;
use Mojolicious::Plugin::AssetPack::Asset;
use Mojolicious::Plugin::AssetPack::Util qw(diag has_ro DEBUG);

my $REQUIRE_JS = path(__FILE__)->dirname->child(qw(Pipe require.js))->realpath;

$ENV{PATH} ||= '';

has topic => '';
has_ro 'assetpack';

sub app { shift->assetpack->ua->server->app }

sub run {
  my ($self, $cmd, @args) = @_;
  my $name = path($cmd->[0])->basename;
  local $cmd->[0] = $self->_find_app($name, $cmd->[0]);
  die qq(@{[ref $self]} was unable to locate the "$name" application.) unless $cmd->[0];
  diag '$ %s', join ' ', @$cmd if DEBUG > 1;
  eval { IPC::Run3::run3($cmd, @args) } or do {
    my $exit = $? > 0 ? $? >> 8 : $?;
    my $bang = int $!;
    die "run($cmd->[0]) failed: $@ (\$?=$exit, \$!=$bang, PATH=$ENV{PATH})";
  };
}

sub process { Carp::confess('Method "process" not implemented by subclass') }

sub _find_app {
  my ($self, $apps, $path) = @_;
  return $path if $path and path($path)->is_abs;

  $apps = [$apps] unless ref $apps eq 'ARRAY';
  for my $name (@$apps) {
    return $self->{apps}{$name} if $self->{apps}{$name};    # Already found
    my $key = uc "MOJO_ASSETPACK_${name}_APP";
    diag 'Looking for "%s" in $%s', $name, $key if DEBUG > 1;
    return $ENV{$key} if $ENV{$key};                        # MOJO_ASSETPACK_FOO_APP wins

    diag 'Looking for "%s" in $PATH.', $name if DEBUG > 1;
    $path = first {-e} map { path($_, $name) } File::Spec->path;
    return $self->{apps}{$name} = $path if $path;           # Found in $PATH
  }

  my $code = $self->can(lc sprintf '_install_%s', $apps->[-1]);
  diag 'Calling %s->_install_%s() ...', ref $self, $apps->[-1] if DEBUG > 1;
  return $self->{apps}{$apps->[-1]} = $self->$code if $code;
  return '';
}

sub _install_node_modules {
  my ($self, @modules) = @_;

  $self->run([$self->_find_app([qw(nodejs node)]), $REQUIRE_JS, @modules], \undef, \my $status);
  $status = Mojo::JSON::decode_json($status);

  for my $plugin (@modules) {
    next unless $status->{$plugin};
    $self->app->log->warn("Installing $plugin... Please wait. (npm install $plugin)");
    $self->run([npm => install => $plugin]);
  }
}

sub _install_gem  { shift->_i('https://rubygems.org/pages/download') }
sub _install_node { shift->_i('https://nodejs.org/en/download') }
sub _install_ruby { shift->_i('https://ruby-lang.org/en/documentation/installation') }
sub _i            { die "@{[ref $_[0]]} requires @{[$_[1]=~/\/(\w+)/?$1:1]}. $_[1]\n" }

sub _run_app {
  my ($self, $asset) = @_;
  my $output = '';
  my ($tmp, @args);

  for my $arg (@{$self->app_args}) {
    if ($arg eq '$input') {
      $tmp = File::Temp->new;
      unshift @args, $tmp;
      push @args, "$tmp";
      defined $tmp->syswrite($asset->content) or die "Can't write to file $tmp: $!";
      close $tmp;
    }
    else {
      push @args, $arg;
    }
  }

  if ($tmp) {
    $self->run([$self->app, @args]);
    $output = path($tmp)->slurp;
  }
  else {
    $self->run([$self->app, @args], \$asset->content, \$output);
  }

  return \$output;
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::AssetPack::Pipe - Base class for a pipe

=head1 SYNOPSIS

=head2 Write a custom pipe

  package MyApp::MyCoolPipe;
  use Mojo::Base "Mojolicious::Plugin::AssetPack::Pipe";
  use Mojolicious::Plugin::AssetPack::Util qw(diag DEBUG);

  sub process {
    my ($self, $assets) = @_;

    # Normally a Mojolicious::Plugin::AssetPack::Store object
    my $store = $self->assetpack->store;

    # Loop over Mojolicious::Plugin::AssetPack::Asset objects
    $assets->each(
      sub {
        my ($asset, $index) = @_;

        # Skip every file that is not css
        return if $asset->format ne "css";

        # Change $attr if this pipe will modify $asset attributes
        my $attr    = $asset->TO_JSON;
        my $content = $asset->content;

        # Private name to load/save meta data under
        $attr->{key} = "coolpipe";

        # Return asset if already processed
        if ($content !~ /white/ and $file = $store->load($attr)) {
          return $asset->content($file);
        }

        # Process asset content
        diag q(Replace white with red in "%s".), $asset->url if DEBUG;
        $content =~ s!white!red!g;
        $asset->content($store->save(\$content, $attr))->minified(1);
      }
    );
  }

=head2 Use the custom pipe

  use Mojolicious::Lite;
  plugin AssetPack => {pipes => [qw(MyApp::MyCoolPipe Css)]};

Note that the above will not load the other default pipes, such as
L<Mojolicious::Plugin::AssetPack::Pipe::JavaScript>.

=head1 DESCRIPTION

This is the base class for all pipe classes.

=head1 ATTRIBUTES

=head2 assetpack

  $obj = $self->assetpack;

Holds a L<Mojolicious::Plugin::AssetPack> object.

=head2 topic

  $str = $self->topic;
  $self = $self->topic("app.css");

Returns the name of the current asset topic.

=head1 METHODS

=head2 after_process

  $self->after_process(Mojo::Collection->new);

L<Mojolicious::Plugin::AssetPack/process> will call this method before
any of the pipe L</process> method is called.

Note that this method is not defined in L<Mojolicious::Plugin::AssetPack::Pipe>!

=head2 app

  $obh = $self->app;

Returns the L<Mojolicious> application object.

=head2 before_process

  $self->before_process(Mojo::Collection->new);

L<Mojolicious::Plugin::AssetPack/process> will call this method after all of
the pipes L</process> method is called.

Note that this method is not defined in L<Mojolicious::Plugin::AssetPack::Pipe>!

=head2 process

  $self->process(Mojo::Collection->new);

A method used to process the assets.
Each of the element in the collection will be a
L<Mojolicious::Plugin::AssetPack::Asset> object or an object with the same
API.

This method need to be defined in the subclass.

=head2 run

  $self->run([som_app => @args], \$stdin, \$stdout, ...);

See L<IPC::Run3/run3> for details about the arguments. This method will try to
call C<_install_some_app()> unless "som_app" was found in
L<PATH|File::Spec/path>. This method could then try to install the application
and must return the path to the installed application.

=head1 SEE ALSO

=over 2

=item * L<Mojolicious::Plugin::AssetPack>

=item * L<Mojolicious::Plugin::AssetPack::Asset>

=item * L<Mojolicious::Plugin::AssetPack::Store>

=item * L<Mojolicious::Plugin::AssetPack::Util>

=back

=cut
