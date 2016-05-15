package Mojolicious::Plugin::AssetPack::Pipe::Reloader;
use Mojo::Base 'Mojolicious::Plugin::AssetPack::Pipe';
use Mojo::Loader ();

use constant CHECK_INTERVAL => $ENV{MOJO_ASSETPACK_CHECK_INTERVAL}  || 0.5;
use constant STRATEGY       => $ENV{MOJO_ASSETPACK_RELOAD_STRATEGY} || 'document';

has input => sub { +{} };
has watch => sub { +{} };

sub before_process {
  my ($self, $assets) = @_;
  $self->input->{$self->topic} = [map { $_->clone } @$assets];
  $self->watch->{$self->topic}
    = [map { ($_->path, @{$_->{dependencies} || []}) } @$assets];
}

sub new {
  my $self  = shift->SUPER::new(@_);
  my $asset = Mojolicious::Plugin::AssetPack::Asset->new(
    content => Mojo::Loader::data_section(__PACKAGE__, 'reloader.js'),
    format  => 'js',
    url     => 'reloader.js',
  );

  $self->app->routes->websocket('/mojo-assetpack-reloader-ws')->to(cb => \&_ws)
    ->name('mojo-assetpack-reloader-ws');

  $asset->content(
    do { local $_ = $asset->content; s!STRATEGY!{STRATEGY}!e; $_ }
  );

  $self->assetpack->process('reloader.js' => $asset);
  $self;
}

sub process { }

sub _ws {
  my $c    = shift;
  my $self = $c->app->asset->pipe('Reloader');
  my $n    = 0;
  my ($tid, %mem, %files);

  while (my ($topic, $files) = each %{$self->watch}) {
    $files{$_} = $topic for grep {$_} @$files;
  }

  $c->on(finish => sub { Mojo::IOLoop->remove($tid) });
  $tid = Mojo::IOLoop->recurring(
    CHECK_INTERVAL,
    sub {
      for my $file (keys %files) {
        $c->send('keep-alive') if ++$n % 10 == 0;
        my ($size, $mtime) = (stat $file)[7, 9];    # Check modify and size
        next unless defined $mtime;
        my $stats = $mem{$file} ||= [$mtime, $size];
        next if $mtime <= $stats->[0] and $size == $stats->[1];
        my $topic = $files{$file};
        my $self  = $c->app->asset->pipe('Reloader');
        warn qq([Pipe::Reloader] File "$file" changed. Processing "$topic"...\n);
        $self->assetpack->process($topic => @{$self->input->{$topic}});
        return $c->finish;
      }
    }
  );
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::AssetPack::Pipe::Reloader - Automatically reload assets in browser

=head1 SYNOPSIS

=head2 Application

  $app->plugin(AssetPack => {pipes => ["Reloader"]);

=head2 Template

  %= asset "reloader.js" if app->mode eq "development"

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Pipe::Reloader> is a pipe which will create
an asset called "reloader.js". This asset will automatically reload the page in
the browser when one of the assets change on disk. This is done without the
need of L<morbo|Mojo::Server::Morbo>.

This feature is EXPERIMENTAL, UNSTABLE and only meant to be used while
developing.

=head1 ENVIRONNMENT

=head2 MOJO_ASSETPACK_RELOAD_STRATEGY

The environment variable C<MOJO_ASSETPACK_RELOAD_STRATEGY> can either be set
to "document" or "inline". "document" means that the whole document should
reload when an asset change, while "inline" will try to figure out which
"link" and "script" tags that changed and only reload those.

The default is "document" for now, but this might change in the future.

=head1 ATTRIBUTES

=head2 input

  $hash = $self->input;

Holds a mapping between the input
L<topic|Mojolicious::Plugin::AssetPack::Pipe/topic> and the list of input
assets.

=head2 watch

  $hash = $self->watch;

Holds a mapping between the input
L<topic|Mojolicious::Plugin::AssetPack::Pipe/topic> and the files on disk to
watch.

=head1 METHODS

=head2 before_process

This method builds up L</input> and L</watch>.

See L<Mojolicious::Plugin::AssetPack::Pipe/before_process>.

=head2 new

Used to add a special "reloader.js" asset and a
"/mojo-assetpack-reloader-ws" WebSocket endpoint.

=head2 process

This method does nothing.

=head1 SEE ALSO

L<Mojolicious::Plugin::AssetPack>.

=cut

__DATA__
@@ reloader.js
window.addEventListener("load", function(e) {
  var script   = document.querySelector('script[src$="/reloader.js"]');
  var reloader = function() {
    var socket = new WebSocket(script.src.replace(/^http/, "ws").replace(/\basset.*/, "mojo-assetpack-reloader-ws"));
    socket.onopen = function() {
      console.log("[AssetPack] Reloader is active.");
    };
    socket.onclose = function() {
      if ("STRATEGY" != "inline") return location = location.href;
      var xhr = new XMLHttpRequest();
      xhr.responseType = "document";
      xhr.open("GET", location.href);
      xhr.onreadystatechange = function() {
        if (xhr.readyState != 4) return;
        var elems = document.querySelectorAll('[src*="/asset/"], [href*="/asset/"]');
        for (i = 0; i < elems.length; i++)
          elems[i].parentNode.removeChild(elems[i]);
        elems = this.responseXML.querySelectorAll('[src*="/asset/"], [href*="/asset/"]');
        for (i = 0; i < elems.length; i++)
          document.body.appendChild(elems[i]);
        reloader();
      };
      xhr.send(null);
    };
  };
  reloader();
});
