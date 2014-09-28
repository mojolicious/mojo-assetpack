package Mojolicious::Plugin::AssetPack::Preprocessors;

=head1 NAME

Mojolicious::Plugin::AssetPack::Preprocessors - Holds preprocessors for the assetpack

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Preprocessors> is used to hold a list of
preprocessors for a given file type.

=head2 SEE ALSO

L<Mojolicious::Plugin::AssetPack::Preprocessor>,
L<Mojolicious::Plugin::AssetPack::Preprocessor::Sass> and
L<Mojolicious::Plugin::AssetPack::Preprocessor::Scss>.

=cut

use Mojo::Base 'Mojo::EventEmitter';
use Mojo::Util ();
use Mojolicious::Plugin::AssetPack::Preprocessor;
use Cwd;
use File::Basename;
use File::Which;
use IPC::Run3 ();

our $VERSION = '0.01';

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

The default preprocessor defined is described under L</detect>.

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

  for my $p (@{ $self->subscribers($extension) }) {
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
    push @checksum, $_->checksum($text, $filename) for @{ $self->subscribers($extension) };
    1;
  } or do {
    $err = $@ || "AssetPack failed with unknown error while processing $filename.\n";
  };

  chdir $old_dir;
  die $err if $err;
  return @checksum == 1 ? $checksum[0] : Mojo::Util::md5_sum(join '', @checksum);
}

=head2 detect

Will add

L<Mojolicious::Plugin::AssetPack::Preprocessor::CoffeeScript>,
L<Mojolicious::Plugin::AssetPack::Preprocessor::Css>,
L<Mojolicious::Plugin::AssetPack::Preprocessor::JavaScript>,
L<Mojolicious::Plugin::AssetPack::Preprocessor::Jsx>,
L<Mojolicious::Plugin::AssetPack::Preprocessor::Less>,
L<Mojolicious::Plugin::AssetPack::Preprocessor::Sass> and
L<Mojolicious::Plugin::AssetPack::Preprocessor::Scss> as preprocessors.

=cut

sub detect {
  my $self = shift;

  require Mojolicious::Plugin::AssetPack::Preprocessor::Css;
  $self->add(css => Mojolicious::Plugin::AssetPack::Preprocessor::Css->new);

  require Mojolicious::Plugin::AssetPack::Preprocessor::CoffeeScript;
  $self->add(coffee => Mojolicious::Plugin::AssetPack::Preprocessor::CoffeeScript->new);

  require Mojolicious::Plugin::AssetPack::Preprocessor::JavaScript;
  $self->add(js => Mojolicious::Plugin::AssetPack::Preprocessor::JavaScript->new);

  require Mojolicious::Plugin::AssetPack::Preprocessor::Less;
  $self->add(less => Mojolicious::Plugin::AssetPack::Preprocessor::Less->new);

  require Mojolicious::Plugin::AssetPack::Preprocessor::Jsx;
  $self->add(jsx => Mojolicious::Plugin::AssetPack::Preprocessor::Jsx->new);

  require Mojolicious::Plugin::AssetPack::Preprocessor::Sass;
  $self->add(sass => Mojolicious::Plugin::AssetPack::Preprocessor::Sass->new);

  require Mojolicious::Plugin::AssetPack::Preprocessor::Scss;
  $self->add(scss => Mojolicious::Plugin::AssetPack::Preprocessor::Scss->new);
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
    $_->($_, $assetpack, $text, $filename) for @{ $self->subscribers($extension) };
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

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
