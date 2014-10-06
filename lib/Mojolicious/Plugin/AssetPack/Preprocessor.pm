package Mojolicious::Plugin::AssetPack::Preprocessor;

=head1 NAME

Mojolicious::Plugin::AssetPack::Preprocessor - Base class for preprocessors

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Preprocessor> is a base class for preprocessors.

=cut

use Mojo::Base -base;
use Mojo::Util ();
use constant DEBUG => $ENV{MOJO_ASSETPACK_DEBUG} || 0;

use overload (q(&{}) => sub { shift->can('process') }, fallback => 1,);

=head1 ATTRIBUTES

=head2 errmsg

Holds the error from last L</process>.

=cut

has errmsg => '';

=head1 METHODS

=head2 can_process

  $bool = $self->can_process;

Returns true.

=cut

sub can_process {1}

=head2 checksum

  $str = $self->checksum($text, $path);

Returns the checksum for a given chunk of C<$text>. C<$text> is a
scalar ref containing the text from the asset. The default is
to use L<Mojo::Util/md5_sum>.

=cut

sub checksum {
  my ($self, $text, $path) = @_;
  Mojo::Util::md5_sum($$text);
}

=head2 process

  $self = $self->process($assetpack, $text, $path);

This method is used to process a given C<$text>. C<$text> is a scalar ref,
holding the text from the asset at location C<$path>. C<$assetpack> is
an L<Mojolicious::Plugin::AssetPack> instance.

=cut

sub process {
  my ($self, $assetpack, $text, $path) = @_;
  die "No pre-processor defined for $path" unless $self->{processor};
  $self->{processor}->($assetpack, $text, $path);
  $self;
}

sub _make_css_error {
  my ($self, $err, $text) = @_;
  $err =~ s!"!'!g;
  $err =~ s!\n!\\A!g;
  $err =~ s!\s! !g;
  $$text
    = qq(html:before{background:#f00;color:#fff;font-size:14pt;position:absolute;padding:20px;z-index:9999;content:"$err";});
  $self->errmsg($err);
  $self;
}

sub _make_js_error {
  my ($self, $err, $text) = @_;
  $err =~ s!'!"!g;
  $err =~ s!\n!\\n!g;
  $err =~ s!\s! !g;
  $$text = "alert('$err');";
  $self->errmsg($err);
  $self;
}

sub _run {
  my ($self, @args) = @_;
  my $cmd       = join(' ', @{$args[0]});
  my $err       = $_[-1];
  my $exit_code = -1;

  $self->errmsg('');
  local ($!, $?, $@);

  eval {
    IPC::Run3::run3(@args);
    $exit_code = $? > 0 ? $? >> 8 : $?;
    $$err ||= sprintf '%s', $! if $?;
  } or do {
    $$err = $@;
    $$err =~ s!\sat\s\S+.*!!s;    # remove " at /some/file.pm line 308"
    chomp $$err;
  };

  warn "[ASSETPACK] $cmd ($exit_code) $$err\n" if DEBUG;
  return $self unless $exit_code;
  $$err = sprintf "AssetPack failed to run '%s'. exit_code=%s %s", $cmd, $exit_code, $$err;
  $self;
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
