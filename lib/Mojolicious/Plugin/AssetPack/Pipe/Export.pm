
package Mojolicious::Plugin::AssetPack::Pipe::Export;

use Mojo::Base 'Mojolicious::Plugin::AssetPack::Pipe';
use Mojo::Util 'spurt';

use File::Basename 'dirname';
use File::Path 'make_path';
use File::Spec;

has 'export_dir';
has 'use_checksum_subdir' => 1;

sub process {
	my ($self, $assets) = @_;

	my $dir = $self->export_dir // $ENV{'MOJO_ASSETPACK_EXPORT_DIR'};
	unless ( defined $dir and -e -w -d $dir ) {
		die "Missing or inaccesable export base directory '$dir'" 
	}

	$assets->each(sub {
		my $asset = shift;

		my $path;
		if ( $self->use_checksum_subdir ) {
			my $file = sprintf( "%s.%s", $asset->name, $asset->format );
			$path = File::Spec->catfile( $dir, $asset->checksum, $file );
		}
		else {
			my $file = sprintf( "%s-%s.%s", $asset->name, $asset->checksum, $asset->format );
			$path = File::Spec->catfile( $dir, $file );
		}
		make_path dirname($path) unless -d dirname($path);
		spurt $asset->content => $path;
	});
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::AssetPack::Pipe::Export - Export processed assets to directory

=head1 SYNOPSIS

  use Mojolicious::Lite;
  
  # "Export" comes last!
  plugin AssetPack => {pipes => [qw(... Export)]};
  app->asset->pipe('Export')->export_dir("/some/path/in/webroot");
  # app->asset->pipe('Export')->use_checksum_subdir(0);

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Pipe::Export> will export the processed assets
to the given directory so you can have them served directly by your webserver.

=head1 ATTRIBUTES

=head2 export_dir

Sets the base directory the assets will be exported to.
If you do not configure this, the environment variable MOJO_ASSETPACK_EXPORT_DIR 
will be used as fallback. If neither value is available, processing will fail with
a C<die()>.

=head2 use_checksum_subdir

Controls how the exported assets are named.

By default and by setting this to a C<true> value, assets will be exported to 
"E<lt>export_dirE<gt>/E<lt>checksumE<gt>/E<lt>assetnameE<gt>.E<lt>assetformatE<gt>".
This corresponds to the route the C<asset>-helper generates by default.

Alternatively you can set C<use_checksum_subdir> to C<false> in which case
the assets will be exported as 
"E<lt>export_dirE<gt>/E<lt>assetnameE<gt>-E<lt>checksumE<gt>.E<lt>assetformatE<gt>".

=head1 METHODS

=head2 process

See L<Mojolicious::Plugin::AssetPack::Pipe/process>.

=head1 SEE ALSO

L<Mojolicious::Plugin::AssetPack>.

=cut
