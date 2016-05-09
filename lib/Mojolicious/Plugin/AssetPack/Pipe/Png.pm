package Mojolicious::Plugin::AssetPack::Pipe::Png;
use Mojo::Base 'Mojolicious::Plugin::AssetPack::Pipe';
use Mojolicious::Plugin::AssetPack::Util qw(diag load_module DEBUG);
use File::Temp ();
use Mojo::Util 'slurp';

has app      => 'pngquant';
has app_args => sub {
  my $self = shift;
  return [DEBUG ? () : ('-quiet'), qw(-clobber -preserve $input)]
    if $self->app eq 'optipng';
  return [DEBUG ? ('-v') : (), qw(--speed 2 -)] if $self->app eq 'pngquant';
  return [];
};

sub process {
  my ($self, $assets) = @_;
  my $store = $self->assetpack->store;
  my $app   = $self->app;
  my $file;

  return $assets->each(
    sub {
      my ($asset, $index) = @_;
      my $attrs = $asset->TO_JSON;
      $attrs->{key} = sprintf '%s-min', $app;
      $attrs->{minified} = 1;
      return if $asset->format ne 'png' or $asset->minified;

      $asset->tag_helper('image');
      return unless $self->assetpack->minify;
      return $asset->content($file)->minified(1) if $file = $store->load($attrs);

      diag 'Process "%s", with checksum %s.', $asset->url, $attrs->{checksum} if DEBUG;
      my ($output, $tmp, @args) = ('');

      for my $arg (@{$self->app_args}) {
        if ($arg eq '$input') {
          $tmp = File::Temp->new;
          push @args, "$tmp";
          defined $tmp->syswrite($asset->content) or die "Can't write to file $tmp: $!";
          close $tmp;
        }
        else {
          push @args, $arg;
        }
      }

      if ($tmp) {
        $self->run([$app, @args]);
        $output = slurp "$tmp";
      }
      else {
        $self->run([$app, @args], \$asset->content, \$output);
      }

      $asset->content($store->save(\$output, $attrs))->FROM_JSON($attrs);
    }
  );
}

sub _install_optipng {
  my $self  = shift;
  my $class = ref $self;
  my $app   = $^O eq 'darwin' ? 'brew' : 'apt-get';    # not very nice
  die "$class requires http://optipng.sourceforge.net/ '$app install optipng'";
}

sub _install_pngquant {
  my $self  = shift;
  my $class = ref $self;
  my $app   = $^O eq 'darwin' ? 'brew' : 'apt-get';    # not very nice
  die "$class requires https://pngquant.org/ '$app install pngquant'";
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::AssetPack::Pipe::Png - Crunch PNG image files

=head2 Application

  plugin AssetPack => {pipes => ["Png"]};

  # Forces the use of "optipng -clobber -preserve $input"
  $self->pipe("Png")->app("optipng");

  # Forces the use of "optipng --speed 2 -"
  $self->pipe("Png")->app("pngquant");

  # Set custom application arguments:
  $self->pipe("Png")->app("pngquant")->app_args([qw(--speed 10 --ordered -)]);

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Pipe::Png> can be used to chrunch "png"
image files.

This plugin has default settings for "pngquant" (default) and "optipng".
Which that will be the default in the future is unknown, so force the
one you want in case that matters.

TODO: Detect which application is installed and use the best available.

TODO: Add support for pngcrush.

=head1 ATTRIBUTES

=head2 app

  $str = $self->app;
  $self = $self->app("optipng");

Can be used to set a custom application instead of "optipng".

=head2 app_args

  $array = $self->app_args;
  $self = $self->app_args([qw(-clobber $input)]);

Can be used to set custom L</app> arguments. The special C<$input> string in
the argument list will be replaced with the path to a temp file holding the
image data.

If no C<$input> element is found in the L</app_args> list, then STDIN and
STDOUT will be used instead.

=head1 METHODS

=head2 process

See L<Mojolicious::Plugin::AssetPack::Pipe/process>.

=head1 SEE ALSO

L<Mojolicious::Plugin::AssetPack>.

=cut
