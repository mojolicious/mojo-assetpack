package Mojolicious::Plugin::Assetpipe::Pipe;
use Mojo::Base -base;
use Mojolicious::Plugin::Assetpipe::Asset;
use Mojolicious::Plugin::Assetpipe::Util 'has_ro';

has topic => '';
has_ro 'assetpipe';

sub app { shift->assetpipe->ua->server->app }

sub new {
  my $self = shift->SUPER::new(@_);
  Scalar::Util::weaken($self->{assetpipe});
  $self;
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::Assetpipe::Pipe - Base class for a pipe

=head1 SYNOPSIS

=head2 Write a custom pipe

  package MyApp::MyCoolPipe;
  use Mojo::Base 'Mojolicious::Plugin::Assetpipe::Pipe';
  use Mojolicious::Plugin::Assetpipe::Util qw(diag DEBUG);

  sub _process {
    my ($self, $assets) = @_;

    # Normally a Mojolicious::Plugin::Assetpipe::Store object
    my $store = $self->assetpipe->store;

    # Loop over Mojolicious::Plugin::Assetpipe::Asset objects
    $assets->each(
      sub {
        my ($asset, $index) = @_;

        # Skip every file that is not css
        return if $asset->format ne 'css';

        # Change $attr if this pipe will modify $asset attributes
        my $attr    = $asset->TO_JSON;
        my $content = $asset->content;

        # Return asset if already processed
        if ($content !~ /white/ and $file = $store->load($attr)) {
          return $asset->content($file);
        }

        # Process asset content
        diag 'Replace white with red in "%s".', $asset->url if DEBUG;
        $content =~ s!white!red!g;
        $asset->content($store->save(\$content, $attr))->minified(1);
      }
    );
  }

=head2 Use the custom pipe

  use Mojolicious::Lite;
  plugin assetpipe => {pipes => [qw(MyApp::MyCoolPipe Css)]};

Note that the above will not load the other default pipes, such as
L<Mojolicious::Plugin::Assetpipe::Pipe::JavaScript>.

=head1 DESCRIPTION

This is the base class for all pipe classes.

=head1 ATTRIBUTES

=head2 assetpipe

  $obj = $self->assetpipe;

Holds a L<Mojolicious::Plugin::Assetpipe> object.

=head2 topic

  $str = $self->topic;
  $self = $self->topic("app.css");

Returns the name of the current asset topic.

=head1 METHODS

=head2 app

  $obh = $self->app;

Returns the L<Mojolicious> application object.

=head2 new

Object constructor. Makes sure L</assetpipe> is weaken.

=head1 SEE ALSO

=over 2

=item * L<Mojolicious::Plugin::Assetpipe>

=item * L<Mojolicious::Plugin::Assetpipe::Asset>

=item * L<Mojolicious::Plugin::Assetpipe::Store>

=item * L<Mojolicious::Plugin::Assetpipe::Util>

=back

=cut
