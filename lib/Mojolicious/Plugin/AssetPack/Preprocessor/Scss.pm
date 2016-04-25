package Mojolicious::Plugin::AssetPack::Preprocessor::Scss;
use Mojo::Base 'Mojolicious::Plugin::AssetPack::Preprocessor';
use Mojo::Util qw(slurp md5_sum);
use File::Basename ();
use File::Spec::Functions 'catfile';
use File::Which ();

use constant DEBUG => $ENV{MOJO_ASSETPACK_DEBUG} || 0;
use constant LIBSASS_BINDINGS => defined $ENV{ENABLE_LIBSASS_BINDINGS}
  ? $ENV{ENABLE_LIBSASS_BINDINGS}
  : eval 'require CSS::Sass;1';

my $IMPORT_RE = qr{ \@import \s+ (["']) (.*?) \1 }x;

has executable => sub { File::Which::which('sass') || 'sass' };
has include_paths => sub { [] };

sub can_process { LIBSASS_BINDINGS || -f $_[0]->executable }

sub checksum {
  my ($self, $text, $path) = @_;
  my $ext           = $path =~ /\.(s[ac]ss)$/ ? $1 : $self->_extension;
  my @include_paths = $self->_include_paths($path);
  my @checksum      = md5_sum $$text;

  local $self->{checked} = $self->{checked} || {};

  while ($$text =~ /$IMPORT_RE/gs) {
    my $path = $self->_import_path(\@include_paths, split('/', $2), $ext) or next;
    warn "[AssetPack] Found \@import $path\n" if DEBUG == 2;
    $self->{checked}{$path}++ and next;
    push @checksum, $self->checksum(\slurp($path), $path);
  }

  return Mojo::Util::md5_sum(join '', @checksum);
}

sub process {
  my ($self, $assetpack, $text, $path) = @_;
  my @include_paths = $self->_include_paths($path);
  my $err;

  if (DEBUG) { local $" = ':'; warn "[AssetPack] SASS_PATH=@include_paths\n" }

  if (LIBSASS_BINDINGS) {
    local $ENV{SASS_PATH} = '';
    my %args = (include_paths => [@include_paths]);
    $args{output_style} = CSS::Sass::SASS_STYLE_COMPRESSED() if $assetpack->minify;
    $$text = CSS::Sass::sass2scss($$text) if $self->_extension eq 'sass';
    ($$text, $err, my $srcmap) = CSS::Sass::sass_compile($$text, %args);
    die $err if $err;
  }
  else {
    local $ENV{SASS_PATH} = join ':', @include_paths;
    my @cmd = ($self->executable, '--stdin');
    push @cmd, '--scss'          if $self->_extension eq 'scss';
    push @cmd, qw(-t compressed) if $assetpack->minify;
    push @cmd, qw(--compass)
      if !$ENV{MOJO_ASSETPACK_NO_COMPASS} and $$text =~ m!\@import\W+compass\/!;
    $self->_run(\@cmd, $text, $text);
  }

  return $self;
}

sub _extension {'scss'}

sub _import_path {
  my ($self, $include_paths, @rel) = @_;
  my ($ext, $name, $path) = (pop @rel, pop @rel);

  for my $p (map { File::Spec->catdir($_, @rel) } @$include_paths) {
    for ("$name.$ext", "_$name.$ext", $name, "_$name") {
      my $f = catfile $p, $_;
      return $f if -f $f and -r _;
    }
  }

  if (DEBUG == 2) {
    local $" = '/';
    warn "[AssetPack] Not found \@import @rel/$name.$ext\n";
  }
  return;
}

sub _include_paths {
  my ($self, $path) = @_;
  my $sass_path = $ENV{SASS_PATH} // '';
  return File::Basename::dirname($path), @{$self->include_paths}, split /:/, $sass_path;
}

sub _url {'http://sass-lang.com/install'}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::AssetPack::Preprocessor::Scss - DEPERACATED

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Preprocessor::Scss> will be DEPERACATED.
Use L<Mojolicious::Plugin::AssetPack::Pipe::Sass> instead.

=head1 ATTRIBUTES

=head2 executable

=head2 include_paths

=head1 METHODS

=head2 can_process

=head2 checksum

=head2 process

=head1 SEE ALSO

L<Mojolicious::Plugin::AssetPack>.

L<http://thorsen.pm/perl/2016/02/21/rewriting-assetpack-plugin.html>

=cut
