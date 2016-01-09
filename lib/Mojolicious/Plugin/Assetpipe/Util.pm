package Mojolicious::Plugin::Assetpipe::Util;
use Mojo::Base 'Exporter';
use Mojo::Util ();

use constant DEBUG   => $ENV{MOJO_ASSETPIPE_DEBUG} || 0;
use constant TESTING => $ENV{HARNESS_IS_VERBOSE}   || 0;

our @EXPORT  = qw( DEBUG diag checksum has_ro );
our $SUM_LEN = 10;
our $TOPIC;

sub checksum {
  substr Mojo::Util::sha1_sum($_[0]), 0, $SUM_LEN;
}

sub diag {
  my $pkg = caller;
  $pkg = 'Assetpipe' unless $pkg =~ s!.*::Assetpipe::Pipe!Assetpipe!;
  warn sprintf "%s[%s%s] %s\n", TESTING ? '# ' : '', $pkg, $TOPIC ? "/$TOPIC" : "",
    join ' ', @_;
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

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::Assetpipe::Util - Description

=head1 VERSION

0.01

=head1 DESCRIPTION

L<Mojolicious::Plugin::Assetpipe::Util> is a ...

=head1 SYNOPSIS

  use Mojolicious::Plugin::Assetpipe::Util;
  my $obj = Mojolicious::Plugin::Assetpipe::Util->new;

=head1 ATTRIBUTES

=head1 METHODS

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut
