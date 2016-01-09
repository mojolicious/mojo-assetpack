package Mojolicious::Plugin::Assetpipe::Util;
use Mojo::Base 'Exporter';
use Mojo::Util ();

use constant DEBUG   => $ENV{MOJO_ASSETPIPE_DEBUG} || 0;
use constant TESTING => $ENV{HARNESS_IS_VERBOSE}   || 0;

our @EXPORT  = qw(DEBUG diag checksum has_ro load_module);
our $SUM_LEN = 10;
our $TOPIC;

sub checksum { substr Mojo::Util::sha1_sum($_[0]), 0, $SUM_LEN }

sub diag {
  my $pkg = caller;
  my $f = @_ > 1 ? shift : '%s';
  $pkg = 'Assetpipe' unless $pkg =~ s!.*::Assetpipe::Pipe!Assetpipe!;
  warn sprintf "%s[%s%s] $f\n", TESTING ? "# " : "", $pkg, $TOPIC ? "/$TOPIC" : "", @_;
}

sub has_ro {
  my ($name, $builder) = @_;
  my $caller = caller;

  if ($builder) {
    Mojo::Util::monkey_patch(
      $caller => $name => sub { $_[0]->{$name} //= $builder->($_[0]) });
  }
  else {
    Mojo::Util::monkey_patch(
      $caller => $name => sub {
        return $_[0]->{$name} if $_[0]->{$name} and @_ == 1;
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

Mojolicious::Plugin::Assetpipe::Util - Description

=head1 DESCRIPTION

L<Mojolicious::Plugin::Assetpipe::Util> is a ...

=head1 SYNOPSIS

  use Mojolicious::Plugin::Assetpipe::Util;
  my $obj = Mojolicious::Plugin::Assetpipe::Util->new;

=head1 ATTRIBUTES

=head1 METHODS

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut
