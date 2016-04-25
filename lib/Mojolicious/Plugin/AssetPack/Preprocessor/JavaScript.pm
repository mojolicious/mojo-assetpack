package Mojolicious::Plugin::AssetPack::Preprocessor::JavaScript;
use Mojo::Base 'Mojolicious::Plugin::AssetPack::Preprocessor';
use constant MINIFIED_LINE_LENGTH => $ENV{JAVASCRIPT_MINIFIED_LINE_LENGTH}
  || 300;    # might change

my $COMMENT_RE = do {
  my $re = sprintf '^\s*(%s)', join '|', map {quotemeta} qw(/* */ //);
  $re = qr{$re};
  $re;
};

sub minify {
  my ($self, $text) = @_;

  # Guess if the input text is already minified
  while ($$text =~ /^(.+)$/mg) {
    my $line = $1;
    next if $line =~ $COMMENT_RE;                          # comments /*, */ and //
    return $self if MINIFIED_LINE_LENGTH < length $line;
  }

  require JavaScript::Minifier::XS;
  $$text = JavaScript::Minifier::XS::minify($$text) if length $$text;
  $self;
}

sub process {
  my ($self, $assetpack, $text, $path) = @_;

  $self->minify($text) if $assetpack->minify;
  $$text .= "\n" if length $$text and $$text !~ /[\n\r]+$/;

  return $self;
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::AssetPack::Preprocessor::JavaScript - DEPRECATED

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Preprocessor::JavaScript> will be DEPRECATED.
Use L<Mojolicious::Plugin::AssetPack::Pipe::JavaScript> instead.

=head1 METHODS

=head2 minify

=head2 process

=head1 SEE ALSO

L<Mojolicious::Plugin::AssetPack>.

L<http://thorsen.pm/perl/2016/02/21/rewriting-assetpack-plugin.html>

=cut
