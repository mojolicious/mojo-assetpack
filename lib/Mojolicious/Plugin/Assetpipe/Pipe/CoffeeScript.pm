package Mojolicious::Plugin::Assetpipe::Pipe::CoffeeScript;
use Mojo::Base 'Mojolicious::Plugin::Assetpipe::Pipe';
use Mojolicious::Plugin::Assetpipe::Util qw(binpath diag run DEBUG);

has _exe => sub {
  my ($self, $path) = @_;
  my $exe = $ENV{MOJO_ASSETPIPE_COFFEE_BIN} // binpath 'coffee';
  return $exe if $exe;

  $self->app->log->warn('Installing coffee... Please wait. (npm install coffee)');
  run [qw(npm install coffee)];
  $self->app->home->rel_file(qw(node_modules .bin coffee));
};

sub _process {
  my ($self, $assets) = @_;
  my $store = $self->assetpipe->store;
  my $file;

  $assets->each(
    sub {
      my ($asset, $index) = @_;
      return if $asset->format ne 'coffee';
      my $attrs = $asset->TO_JSON;
      @$attrs{qw(format key)} = qw(js coffee);
      return $asset->content($file)->FROM_JSON($attrs) if $file = $store->load($attrs);
      diag 'Process "%s" with checksum %s.', $asset->url, $attrs->{checksum} if DEBUG;
      run [$self->_exe, '--compile', '--stdio'], \$asset->content, \my $js, undef;
      $asset->content($store->save(\$js, $attrs))->FROM_JSON($attrs);
    }
  );
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::Assetpipe::Pipe::CoffeeScript - Process CoffeeScript

=head1 DESCRIPTION

L<Mojolicious::Plugin::Assetpipe::Pipe::CoffeeScript> will process
L<http://coffeescript.org/> files into JavaScript.

This module require the C<coffee> executable to be installed. C<coffee> will be
automatically installed using L<https://www.npmjs.com/> unless already
installed.

=head1 SEE ALSO

L<Mojolicious::Plugin::Assetpipe>.

=cut
