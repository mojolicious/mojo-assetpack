package Mojolicious::Plugin::AssetPack::Preprocessors;
use Mojo::Base 'Mojo::EventEmitter';
use Mojo::Util ();
use Mojolicious::Plugin::AssetPack::Preprocessor;
use File::Basename;
use File::Which;
use IPC::Run3 ();
use constant DEBUG => $ENV{MOJO_ASSETPACK_DEBUG} || 0;

our $VERSION = '0.01';

my %PREPROCESSORS = (
  coffee => 'Mojolicious::Plugin::AssetPack::Preprocessor::CoffeeScript',
  css    => 'Mojolicious::Plugin::AssetPack::Preprocessor::Css',
  js     => 'Mojolicious::Plugin::AssetPack::Preprocessor::JavaScript',
  jsx    => 'Mojolicious::Plugin::AssetPack::Preprocessor::Jsx',
  less   => 'Mojolicious::Plugin::AssetPack::Preprocessor::Less',
  sass   => 'Mojolicious::Plugin::AssetPack::Preprocessor::Sass',
  scss   => 'Mojolicious::Plugin::AssetPack::Preprocessor::Scss',
);

has fallback => sub {
  require Mojolicious::Plugin::AssetPack::Preprocessor::Fallback;
  Mojolicious::Plugin::AssetPack::Preprocessor::Fallback->new;
};

sub add {
  my ($self, $extension, $arg) = @_;

  # create object
  if (@_ == 4) {
    my $class
      = $arg =~ /::/ ? $arg : "Mojolicious::Plugin::AssetPack::Preprocessor::$arg";
    eval "require $class;1" or die "Could not load $class: $@\n";
    warn "[AssetPack] Adding $class preprocessor for $extension.\n" if DEBUG;
    my $object = $class->new(pop);
    return $self->add($extension => $object);
  }

  # back compat
  if (ref $arg eq 'CODE') {
    $arg = Mojolicious::Plugin::AssetPack::Preprocessor->new(processor => $arg);
  }

  $self->on($extension => $arg);
}

sub can_process {
  my ($self, $extension) = @_;

  for my $p ($self->_preprocessors($extension)) {
    return 1 if $p->can_process;
  }

  return 0;
}

sub checksum {
  my ($self, $extension, $text, $filename) = @_;
  my $cwd = Mojolicious::Plugin::AssetPack::Preprocessors::CWD->new(dirname $filename);
  my @checksum;

  for my $p ($self->_preprocessors($extension)) {
    $p->cwd($cwd->[0]);
    push @checksum, $p->checksum($text, $filename);
  }

  return @checksum == 1 ? $checksum[0] : Mojo::Util::md5_sum(join '', @checksum);
}

sub process {
  my ($self, $extension, $assetpack, $text, $filename) = @_;
  my $cwd = Mojolicious::Plugin::AssetPack::Preprocessors::CWD->new(dirname $filename);
  my @err;

  for my $p ($self->_preprocessors($extension)) {
    $p->cwd($cwd->[0]);
    $p->($p, $assetpack, $text, $filename);
  }

  return $self;
}

sub remove { shift->unsubscribe(@_) }

sub _preprocessors {
  my ($self, $extension) = @_;
  my @preprocessors = @{$self->subscribers($extension)};

  return @preprocessors if @preprocessors;
  my $class = $PREPROCESSORS{$extension};
  return $self->add($extension => $class => {}) if $class;
  return $self->fallback;
}

package Mojolicious::Plugin::AssetPack::Preprocessors::CWD;
use Cwd;
sub new { my $self = bless [getcwd], $_[0]; chdir $_[1]; return $self; }
sub DESTROY { chdir $_[0]->[0]; }

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::AssetPack::Preprocessors - DEPRECATED

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Preprocessors> will be DEPRECATED.

=head1 ATTRIBUTES

=head2 fallback

=head1 METHODS

=head2 add

=head2 can_process

=head2 checksum

=head2 process

=head2 map_type

=head2 remove

=head1 SEE ALSO

L<Mojolicious::Plugin::AssetPack>

=cut
