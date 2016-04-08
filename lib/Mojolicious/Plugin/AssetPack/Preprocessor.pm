package Mojolicious::Plugin::AssetPack::Preprocessor;
use Mojo::Base -base;
use Mojo::JSON 'encode_json';
use Mojo::Util ();
use Cwd        ();
use POSIX      ();
use constant DEBUG => $ENV{MOJO_ASSETPACK_DEBUG} || 0;

use overload (q(&{}) => sub { shift->can('process') }, fallback => 1,);

has cwd => sub {Cwd::getcwd};

sub can_process {1}

sub checksum {
  my ($self, $text, $path) = @_;
  Mojo::Util::md5_sum($$text);
}

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
  warn "[AssetPack] @$cmd \$?=$? \$!=$! $err\n" if DEBUG;

  return $self unless $?;
  die sprintf "Cannot execute '%s'. See %s\n", $cmd->[0], $self->_url if $! == 2;
  die sprintf "Failed to run '%s' (\$?=%s, \$!=%s) %s", join(' ', @$cmd), $? >> 8,
    int($!), $err;
}

sub _url {'https://metacpan.org/pod/Mojolicious::Plugin::AssetPack::Preprocessors'}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::AssetPack::Preprocessor - DEPRECATED

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Preprocessor> will be DEPRECATED.

=head1 ATTRIBUTES

=head2 cwd

=head1 METHODS

=head2 can_process

=head2 checksum

=head2 process

=head1 SEE ALSO

L<Mojolicious::Plugin::AssetPack>.

=cut
