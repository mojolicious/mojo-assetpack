package Mojolicious::Plugin::AssetPack::Pipe::Less;
use Mojo::Base 'Mojolicious::Plugin::AssetPack::Pipe';

use Mojolicious::Plugin::AssetPack::Util qw(diag $CWD DEBUG);

sub process {
  my ($self, $assets) = @_;
  my $store = $self->assetpack->store;
  my $file;

  $assets->each(sub {
    my ($asset, $index) = @_;
    return if $asset->format ne 'less';
    my $attrs = $asset->TO_JSON;
    @$attrs{qw(format key)} = qw(css less);
    return $asset->content($file)->FROM_JSON($attrs) if $file = $store->load($attrs);
    diag 'Process "%s" with checksum %s.', $asset->url, $attrs->{checksum} if DEBUG;
    my @args = qw(lessc --no-color);
    my $file = $asset->path ? $asset : Mojo::Asset::File->new->add_chunk($asset->content);
    push @args, '--include-path=' . $asset->path->dirname if $asset->path;
    push @args, $file->path;
    $self->run(\@args, undef, \my $css);
    $asset->content($store->save(\$css, $attrs))->FROM_JSON($attrs);
  });
}

sub _install_lessc {
  my $self = shift;
  my $bin  = $self->app->home->rel_file('node_modules/.bin/lessc');
  return $bin if -e $bin;
  local $CWD = $self->app->home->to_string;
  $self->app->log->warn('Installing lessc... Please wait. (npm install less)');
  $self->run([qw(npm install less)]);
  return $bin;
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::AssetPack::Pipe::Less - Process Less CSS files

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Pipe::Less> will process
L<http://lesscss.org/> files into JavaScript.

This module require the C<less> executable to be installed. C<less> will be
automatically installed using L<https://www.npmjs.com/> unless already
installed.

=head1 METHODS

=head2 process

See L<Mojolicious::Plugin::AssetPack::Pipe/process>.

=head1 SEE ALSO

L<Mojolicious::Plugin::AssetPack>.

=cut
