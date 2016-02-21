package Mojolicious::Plugin::AssetPack::Pipe;
use Mojo::Base -base;
use Mojolicious::Plugin::AssetPack::Asset;
use Mojolicious::Plugin::AssetPack::Util qw(diag has_ro DEBUG);
use File::Basename ();
use IPC::Run3      ();
use List::Util 'first';

$ENV{PATH} ||= '';

has topic => '';
has_ro 'assetpack';

sub app { shift->assetpack->ua->server->app }

sub new {
  my $self = shift->SUPER::new(@_);
  Scalar::Util::weaken($self->{assetpack});
  $self;
}

sub run {
  my ($self, $cmd, @args) = @_;
  my $name = File::Basename::basename($cmd->[0]);
  local $cmd->[0] = $self->_find_app($name, $cmd->[0]);
  die qq(@{[ref $self]} was unable to locate the "$name" application.) unless $cmd->[0];
  $self->app->log->debug(join ' ', '[AssetPack]', @$cmd);
  eval { IPC::Run3::run3($cmd, @args) } or do {
    my $exit = $? > 0 ? $? >> 8 : $?;
    my $bang = int $!;
    die "run($cmd->[0]) failed: $@ (\$?=$exit, \$!=$bang, PATH=$ENV{PATH})";
  };
}

sub process { Carp::confess('Method "process" not implemented by subclass') }

sub _find_app {
  my ($self, $name, $path) = @_;
  return $path if $path and File::Spec->file_name_is_absolute($path);

  my $key = uc "MOJO_ASSETPACK_${name}_APP";
  diag 'Looking for "%s" in %s', $name, $key if DEBUG > 1;
  return $ENV{$key} if $ENV{$key};

  return $self->{apps}{$name} if $self->{apps}{$name};
  diag 'Looking for "%s" in PATH.', $name if DEBUG > 1;
  $path = first {-e} map { File::Spec->catfile($_, $name) } File::Spec->path;
  return $self->{apps}{$name} = $path if $path;

  my $code = $self->can(lc sprintf '_install_%s', $name);
  diag 'Calling %s->_install_%s() ...', ref $self, $name if DEBUG > 1;
  return $self->{apps}{$name} = $self->$code if $code;
  return '';
}

sub _install_gem  { shift->_i('https://rubygems.org/pages/download') }
sub _install_node { shift->_i('https://nodejs.org/en/download') }
sub _install_ruby { shift->_i('https://ruby-lang.org/en/documentation/installation') }
sub _i            { die "@{[ref $_[0]]} requires @{[$_[1]=~/\/(\w+)/?$1:1]}. $_[1]\n" }

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

=head2 app

  $obh = $self->app;

Returns the L<Mojolicious> application object.

=head2 new

Object constructor. Makes sure L</assetpack> is weaken.

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
