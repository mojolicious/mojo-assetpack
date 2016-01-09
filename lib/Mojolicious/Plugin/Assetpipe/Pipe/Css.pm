package Mojolicious::Plugin::Assetpipe::Pipe::Css;
use Mojo::Base 'Mojolicious::Plugin::Assetpipe::Pipe';
use Mojolicious::Plugin::Assetpipe::Util qw(diag load_module DEBUG);

sub _process {
  my ($self, $assets) = @_;
  my $l;

  return unless $self->assetpipe->minify;
  return $assets->each(
    sub {
      my ($asset, $index) = @_;
      return if $asset->format ne 'css' or $asset->minified;
      load_module 'CSS::Minifier::XS'
        or die qq(Could not to load "CSS::Minifier::XS": $@)
        unless $l++;

      diag 'Minify "%s" with checksum "%s".', $asset->url, $asset->checksum if DEBUG;
      $asset->checksum;    # make sure checksum() is calculated before changing content()
      $asset->content(CSS::Minifier::XS::minify($asset->content))->minified(1);
    }
  );
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::Assetpipe::Pipe::Css - Description

=head1 DESCRIPTION

L<Mojolicious::Plugin::Assetpipe::Pipe::Css> is a ...

=head1 SYNOPSIS

  use Mojolicious::Plugin::Assetpipe::Pipe::Css;
  my $obj = Mojolicious::Plugin::Assetpipe::Pipe::Css->new;

=head1 ATTRIBUTES

=head1 METHODS

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut
