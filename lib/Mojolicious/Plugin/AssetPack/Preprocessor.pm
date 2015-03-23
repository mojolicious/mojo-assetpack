package Mojolicious::Plugin::AssetPack::Preprocessor;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::AssetPack::Preprocessor - Base class for preprocessors

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Preprocessor> is a base class for preprocessors.

=cut

use Mojo::Base -base;
use Mojo::JSON 'encode_json';
use Mojo::Util ();
use Cwd        ();
use POSIX      ();
use constant DEBUG => $ENV{MOJO_ASSETPACK_DEBUG} || 0;

use overload (q(&{}) => sub { shift->can('process') }, fallback => 1,);

=head1 ATTRIBUTES

=head2 cwd

Path to the current directory, before L<Mojolicious::Plugin::AssetPack::Preprocessor>
did any C<chdir>.

=head2 errmsg

DEPRECATED

=cut

has cwd => sub {Cwd::getcwd};

sub errmsg { die $_[1] }

=head1 METHODS

=head2 can_process

  $bool = $self->can_process;

Returns true.

=cut

sub can_process {1}

=head2 checksum

  $str = $self->checksum($text, $path);

Returns the checksum for a given chunk of C<$text>. C<$text> is a
scalar ref containing the text from the asset. The default is
to use L<Mojo::Util/md5_sum>.

=cut

sub checksum {
  my ($self, $text, $path) = @_;
  Mojo::Util::md5_sum($$text);
}

=head2 process

  $self = $self->process($assetpack, $text, $path);

This method is used to process a given C<$text>. C<$text> is a scalar ref,
holding the text from the asset at location C<$path>. C<$assetpack> is
an L<Mojolicious::Plugin::AssetPack> instance.

=cut

sub process {
  my ($self, $assetpack, $text, $path) = @_;
  die "No pre-processor defined for $path" unless $self->{processor};
  $self->{processor}->($assetpack, $text, $path);
  $self;
}

sub _run {
  my ($self, $cmd, $in, $out) = @_;
  my $err = '';

  local ($!, $?) = (0, -1);
  IPC::Run3::run3($cmd, $in, $out, \$err, {return_if_system_error => 1});
  $! = 0 if !$? and $! == POSIX::ENOTTY;
  warn "[ASSETPACK] @$cmd \$?=$? \$!=$! $err\n" if DEBUG;

  return $self unless $?;
  die sprintf "Cannot execute '%s'. See %s\n", $cmd->[0], $self->_url if $! == 2;
  die sprintf "Failed to run '%s' (\$?=%s, \$!=%s) %s", join(' ', @$cmd), $? >> 8, int($!), $err;
}

sub _url {'https://metacpan.org/pod/Mojolicious::Plugin::AssetPack::Preprocessors'}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
