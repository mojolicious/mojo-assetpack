package Mojolicious::Plugin::Assetpipe::Util;
use Mojo::Base 'Exporter';
use Mojo::Util ();

use constant DEBUG => $ENV{MOJO_ASSETPIPE_DEBUG} || 0;
use constant SILENT => $ENV{HARNESS_ACTIVE}
  && !$ENV{HARNESS_IS_VERBOSE} ? !$ENV{TEST_DIAG} : 0;
use constant TESTING => $ENV{HARNESS_IS_VERBOSE} || 0;

our @EXPORT  = qw(diag checksum has_ro load_module DEBUG);
our $SUM_LEN = 10;
our $TOPIC;

sub checksum { substr Mojo::Util::sha1_sum($_[0]), 0, $SUM_LEN }

sub diag {
  return if SILENT;
  my $f = @_ > 1 ? shift : '%s';
  my ($i, $pkg) = (0);
  while ($pkg = caller $i++) { $pkg =~ s!.*::(Assetpipe::)Pipe::!$1! and last }
  $pkg = 'Assetpipe' unless $pkg;
  warn sprintf "%s[%s%s] $f\n", TESTING ? "# " : "", $pkg, $TOPIC ? "/$TOPIC" : "", @_;
}

sub has_ro {
  my ($name, $builder) = @_;
  my $caller = caller;

  if ($builder) {
    Mojo::Util::monkey_patch(
      $caller => $name => sub {
        Carp::confess(qq("$name" is read-only")) if @_ > 1;
        $_[0]->{$name} //= $builder->($_[0]);
      }
    );
  }
  else {
    Mojo::Util::monkey_patch(
      $caller => $name => sub {
        Carp::confess(qq("$name" is read-only")) if @_ > 1;
        return $_[0]->{$name} if exists $_[0]->{$name};
        Carp::confess(qq("$name" is required in constructor'));
      }
    );
  }
}

sub load_module {
  my $module = shift;
  eval "require $module;1";
  return $@ ? '' : $module;
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::Assetpipe::Util - Utility functions for pipes

=head1 DESCRIPTION

L<Mojolicious::Plugin::Assetpipe::Util> holds utility functions.

=head1 SYNOPSIS

  use Mojolicious::Plugin::Assetpipe::Util;
  use Mojolicious::Plugin::Assetpipe::Util qw(checksum diag DEBUG)

=head1 FUNCTIONS

=head2 checksum

  $str = checksum $bytes;

Used to calculate checksum of C<$bytes>.

=head2 diag

  diag "some messsage";
  diag "some %s", "messsage";

Same as C<warn()>, but with a prefix. It will also use C<sprintf()> if
more than one argument is given.

=head2 has_ro

Same as L<Mojo::Base/has>, but creates a read-only attribute.

=head2 load_module

  $module = load_module $module;

Used to load C<$module>. Echo back C<$module> on success and returns empty
string on failure. C<$@> holds the error message on failure.

=head1 SEE ALSO

L<Mojolicious::Plugin::Assetpipe>.

=cut
