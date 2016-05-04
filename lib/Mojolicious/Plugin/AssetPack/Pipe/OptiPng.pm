
package Mojolicious::Plugin::AssetPack::Pipe::OptiPng;

use Mojo::Base 'Mojolicious::Plugin::AssetPack::Pipe';
use Mojo::Util qw( spurt slurp );
use File::Temp qw( tempfile );

sub process {
	my ($self, $assets) = @_;
	my $store = $self->assetpack->store;
	my $file;

	$assets->each(
		sub {
			my ($asset, $index) = @_;

			# might also use optipng to convert BMP, GIF, PNM or TIFF to PNG
			# but not yet
			return unless $asset->format eq 'png';

			my $attrs = $asset->TO_JSON;
			$attrs->{key}    = 'optipng';
			$attrs->{format} = 'png';

			# already processed before?
			return $asset->content($file)->FROM_JSON($attrs) if $file = $store->load($attrs);

			my ( $content, $error );
			{
				my ( $fh, $file ) = tempfile();
				spurt $store->load($asset), $file;

				my ( $in, $out, $err ) = ( '', '', '' );
				my @cmd = ( 'optipng', '-quiet', '-clobber', $file );

				eval { IPC::Run3::run3(\@cmd, \$in, \$out, \$err) } or do {
					my $exit = $? > 0 ? $? >> 8 : $?;
					my $bang = int $!;
					$error = "optipng failed: $@ (\$?=$exit, \$!=$bang, PATH=$ENV{PATH})";
				};

				# Using "-quiet" above: should be nothing in here
				if ($err) {
					$error = "optipng failed: $err";
				}

				$content = slurp $file;

				$error = "Running optipng did not produce any output" unless $content;
			}
			die $error if $error;

			$asset->content($store->save(\$content, $attrs))->FROM_JSON($attrs);
		}
	);
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::AssetPack::Pipe::OptiPng - Optimize PNG images using OptiPng.

=head1 SYNOPSIS

  use Mojolicious::Lite;
  
  plugin AssetPack => {pipes => [qw(OptiPng)]};

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Pipe::OptiPng> will try to optimize PNG assets
by running B<OptiPng>.
Please note that the C<optipng> programm must be in your C<PATH>; otherwise it
will not be found and processing will fail.

Currently you cannot modify the settings for running C<optipng>. 
Furthermore, while C<optipng> would also accept C<BMP>, C<GIF>, C<PNM> or C<TIFF>
input files (but create C<PNG>s from them) this is not (yet?) supported.

=head1 METHODS

=head2 process

See L<Mojolicious::Plugin::AssetPack::Pipe/process>.

=head1 SEE ALSO

L<http://optipng.sourceforge.net/>.
L<Mojolicious::Plugin::AssetPack>.

=cut
