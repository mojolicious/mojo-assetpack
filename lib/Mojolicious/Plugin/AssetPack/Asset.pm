package Mojolicious::Plugin::AssetPack::Asset;

use Mojo::Base -base;
use File::Basename 'dirname';
use Fcntl qw( O_CREAT O_EXCL O_RDONLY O_RDWR );
use IO::File;

has handle => sub {
  my $self   = shift;
  my $path   = $self->path;
  my $handle = IO::File->new;
  my $mode   = -w $path ? O_RDWR : -w dirname($path) ? O_CREAT | O_EXCL | O_RDWR : O_RDONLY;

  $handle->open($path, $mode) or die "Can't open $path: $!";
  $handle;
};

has path => undef;

sub add_chunk {
  my $self = shift;
  defined $self->handle->syswrite($_[0]) or die "Can't write to @{[$self->path]}: $!";
  return $self;
}

sub slurp {
  my $self   = shift;
  my $handle = $self->handle;
  $handle->sysseek(0, 0);
  defined $handle->sysread(my $content, -s $handle, 0) or die "Can't read from @{[$self->path]}: $!";
  return $content;
}

sub spurt {
  my $self   = shift;
  my $handle = $self->handle;
  $handle->truncate(0);
  $handle->sysseek(0, 0);
  defined $handle->syswrite($_[0]) or die "Can't write to @{[$self->path]}: $!";
  return $self;
}

sub _spurt_error_message_for {
  my ($self, $ext, $err) = @_;

  $err =~ s!\r!!g;
  $err =~ s!\n+$!!;

  if ($ext eq 'js') {
    $err =~ s!'!"!g;
    $err =~ s!\n!\\n!g;
    $err =~ s!\s! !g;
    $err = "alert('$err');console.log('$err');";
  }
  else {
    $err =~ s!"!'!g;
    $err =~ s!\n!\\A!g;
    $err =~ s!\s! !g;
    $err
      = qq(html:before{background:#f00;color:#fff;font-size:14pt;position:fixed;padding:20px;z-index:9999;content:"$err";});
  }

  $self->spurt($err);
}

1;
__END__

=head1 NAME

Mojolicious::Plugin::AssetPack::Asset - Represents an asset file

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Asset> is class that can represent a file
on disk.

This class is EXPERIMENTAL.

=head1 ATTRIBUTES

=head2 handle

  $fh = $self->handle;
  $self = $self->handle($fh);

Returns a filehandle to L</path> with the correct read/write mode,
dependent on the file system permissions.

=head2 path

  $str = $self->path;
  $self = $self->path($str);

Holds the location of the file.

=head1 METHODS

=head2 add_chunk

  $self = $self->add_chunk($chunk);

Will append a C<$chunk> to the L</path>.

=head2 slurp

  $content = $self->slurp;

Will return the contents of L</path>.

=head2 spurt

  $self = $self->spurt($content);

Used to truncate and write C<$content> to L</path>.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2015, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut
