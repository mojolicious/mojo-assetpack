package Mojolicious::Plugin::AssetPack::Preprocessors;

=head1 NAME

Mojolicious::Plugin::AssetPack::Preprocessors - Holds preprocessors for the assetpack

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Preprocessors> is used to hold a list of
preprocessors for a given file type.

=head2 Bundled preprocessors

=over 4

=item * L<Mojolicious::Plugin::AssetPack::Preprocessor::CoffeeScript>

=item * L<Mojolicious::Plugin::AssetPack::Preprocessor::Css>

=item * L<Mojolicious::Plugin::AssetPack::Preprocessor::JavaScript>

=item * L<Mojolicious::Plugin::AssetPack::Preprocessor::Jsx>

=item * L<Mojolicious::Plugin::AssetPack::Preprocessor::Less>

=item * L<Mojolicious::Plugin::AssetPack::Preprocessor::Sass>

=item * L<Mojolicious::Plugin::AssetPack::Preprocessor::Scss>

=cut

use Mojo::Base 'Mojo::EventEmitter';
use Mojo::Util ();
use Mojolicious::Plugin::AssetPack::Preprocessor;
use Cwd;
use File::Basename;
use File::Which;
use IPC::Run3 ();
use constant DEBUG => $ENV{MOJO_ASSETPACK_DEBUG} || 0;

our $VERSION = '0.01';

my %PREPROCESSORS = (
  coffee => 'Mojolicious::Plugin::AssetPack::Preprocessor::CoffeeScript',
  css => 'Mojolicious::Plugin::AssetPack::Preprocessor::Css',
  js => 'Mojolicious::Plugin::AssetPack::Preprocessor::JavaScript',
  jsx => 'Mojolicious::Plugin::AssetPack::Preprocessor::Jsx',
  less => 'Mojolicious::Plugin::AssetPack::Preprocessor::Less',
  sass => 'Mojolicious::Plugin::AssetPack::Preprocessor::Sass',
  scss => 'Mojolicious::Plugin::AssetPack::Preprocessor::Scss',
);

=head1 METHODS

=head2 add

  $self->add($extension => $object);

  $self->add($extension => sub {
    my ($assetpack, $text, $file) = @_;
    $$text =~ s/foo/bar/ if $file =~ /baz/ and $assetpack->minify;
  });

Define a preprocessor which is run on a given file extension. These
preprocessors will be chained. The callbacks will be called in the order they
where added.

In case of C<$object>, the object need to be able to have the C<process()>
method.

=cut

sub add {
  my ($self, $extension, $arg) = @_;

  # back compat
  if (ref $arg eq 'CODE') {
    $arg = Mojolicious::Plugin::AssetPack::Preprocessor->new(processor => $arg);
  }

  $self->on($extension => $arg);
}

=head2 can_process

  $bool = $self->can_process($extension);

Returns true if there is at least one of the preprocessors L<added|/add>
can handle this extensions.

This means that a preprocessor object can be added, but is unable to
actually process the asset. This is a helper method, which can be handy
in unit tests to check if "sass", "jsx" or other preprocessors are
actually installed.

=cut

sub can_process {
  my ($self, $extension) = @_;

  for my $p ($self->_preprocessors($extension)) {
    return 1 if $p->can_process;
  }

  return 0;
}

=head2 checksum

  $str = $self->checksum($extension => \$text, $filename);

Calls the C<checksum()> method in all the preprocessors for the C<$extension>
and returns a combined checksum.

=cut

sub checksum {
  my($self, $extension, $text, $filename) = @_;
  my $old_dir = getcwd;
  my $err = '';
  my @checksum;

  local $@;

  eval {
    chdir dirname $filename if $filename;
    push @checksum, $_->checksum($text, $filename) for $self->_preprocessors($extension);
    1;
  } or do {
    $err = $@ || "AssetPack failed with unknown error while processing $filename.\n";
  };

  chdir $old_dir;
  die $err if $err;
  return @checksum == 1 ? $checksum[0] : Mojo::Util::md5_sum(join '', @checksum);
}

=head2 detect

DEPRECATED. Default handlers are added on the fly.

=cut

sub detect {
  warn "DEPRECATED".
  $_[0];
}

=head2 process

  $self->process($extension => $assetpack, \$text, $filename);

Will run the preprocessor callbacks added by L</add>. The callbacks will be
called with the C<$assetpack> object as the first argument.

=cut

sub process {
  my($self, $extension, $assetpack, $text, $filename) = @_;
  my $old_dir = getcwd;
  my $err = '';

  local $@;

  eval {
    chdir dirname $filename;
    $_->($_, $assetpack, $text, $filename) for $self->_preprocessors($extension);
    1;
  } or do {
    $err = $@ || "AssetPack failed with unknown error while processing $filename.\n";
  };

  chdir $old_dir;
  die $err if $err;
  $self;
}

=head2 map_type

DEPRECATED: The mapping is already done based on input files.

=head2 remove

  $self->remove($extension);
  $self->remove($extension => $cb);

This method will remove all preprocessors defined for an extension, or just a
given C<$cb>.

=cut

sub remove { shift->unsubscribe(@_) }

sub _preprocessors {
  my ($self, $extension) = @_;
  my @preprocessors = @{ $self->subscribers($extension) };

  return @preprocessors if @preprocessors;

  if (my $class = $PREPROCESSORS{$extension}) {
    warn "[ASSETPACK] Adding $class preprocessor.\n" if DEBUG;
    eval "require $class;1" or die "Could not load $class: $@\n";
    return $self->add($extension => $class->new);
  }

  return;
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
