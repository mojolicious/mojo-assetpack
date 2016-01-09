package Mojolicious::Plugin::Assetpipe::Pipe::Combine;
use Mojo::Base 'Mojolicious::Plugin::Assetpipe::Pipe';
use Mojolicious::Plugin::Assetpipe::Util qw(checksum diag DEBUG);

sub _combine {
  my ($self, $assets) = @_;

  return unless $self->assetpipe->minify;
  my $checksum = checksum $assets->map('checksum')->join(':');
  diag 'Combining assets into "%s" with checksum %s.', $self->topic, $checksum if DEBUG;
  @$assets = ($assets->first->new(assetpipe => $self->assetpipe, url => $self->topic)
      ->checksum($checksum)->content($assets->map('content')->join("\n")));
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::Assetpipe::Pipe::Combine - Description

=head1 DESCRIPTION

L<Mojolicious::Plugin::Assetpipe::Pipe::Combine> is a ...

=head1 SYNOPSIS

  use Mojolicious::Plugin::Assetpipe::Pipe::Combine;
  my $obj = Mojolicious::Plugin::Assetpipe::Pipe::Combine->new;

=head1 ATTRIBUTES

=head1 METHODS

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut
