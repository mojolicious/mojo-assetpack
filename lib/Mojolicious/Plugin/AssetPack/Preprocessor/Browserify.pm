package Mojolicious::Plugin::Browserify::Processor;

=head1 NAME

Mojolicious::Plugin::Browserify::Processor - An AssetPack processor for browserify

=head1 DESCRIPTION

L<Mojolicious::Plugin::Browserify::Processor> is a
L<Mojolicious::Plugin::AssetPack> preprocessor.

=head1 SYNOPSIS

  use Mojolicious::Lite;

  plugin "AssetPack";
  app->asset->preprocessors->remove($_) for qw( js jsx );

  my $browserify = Mojolicious::Plugin::Browserify::Processor->new;
  app->asset->preprocessors->add($browserify);
  app->asset("app.js" => "/js/main.js");

  get "/app" => "app_js_inlined";
  app->start;

  __DATA__
  @@ app_js_inlined.js.ep
  %= asset "app.js" => {inline => 1}

See also L<Mojolicious::Plugin::Browserify> for a simpler API.

=cut

use Mojo::Base 'Mojolicious::Plugin::AssetPack::Preprocessor';
use Mojo::Util;
use Cwd ();
use File::Basename 'dirname';
use File::Path 'make_path';
use File::Spec;
use File::Which ();
use constant DEBUG => $ENV{MOJO_ASSETPACK_DEBUG} || 0;
use constant CACHE_DIR => '.browserify';

=head1 ATTRIBUTES

=head2 browserify_args

  $array_ref = $self->browserify_args;
  $self= $self->browserify_args([ -g => "reactify" ]);

Command line arguments that will be passed on to C<browserify>.

=head2 environment

  $str = $self->environment;
  $self = $self->environment($str);

Should be either "production" or "development" (default). This variable will
be passed on as C<NODE_ENV> to C<browserify>.

=head2 extensions

  $array_ref = $self->extensions;
  $self = $self->extensions([qw( js jsx )]);

Specifies the extensions browserify should look for.

=head2 executable

  $path = $self->executable;

Holds the path to the "browserify" executable. Default to just "browserify".
C<browserify> can also be found in C<./node_modules/.bin/browserify>, in the
current project directory.

=cut

has browserify_args => sub { [] };
has environment     => sub { $ENV{MOJO_MODE} || $ENV{NODE_ENV} || 'development' };
has extensions      => sub { ['js'] };
has executable => sub { shift->_executable('browserify') || 'browserify' };

=head1 METHODS

=head2 can_process

  $bool = $self->can_process;

Returns true if browserify can be executed.

=cut

sub can_process { -f $_[0]->executable ? 1 : 0 }

=head2 checksum

  $str = $self->checksum($text, $path);

Returns the checksum for a given chunk of C<$text>. C<$text> is a
scalar ref containing the text from the asset. The default is
to use L<Mojo::Util/md5_sum>.

=cut

sub checksum {
  my ($self, $text, $path) = @_;
  my $map = {};

  $self->_node_module_path;
  $self->_find_node_modules($text, $path, $map);
  Mojo::Util::md5_sum($$text, join '', map { Mojo::Util::slurp($map->{$_}) } sort keys %$map);
}

=head2 process

Used to process the JavaScript using C<browserify>.

=cut

sub process {
  my ($self, $assetpack, $text, $path) = @_;
  my $environment = $self->environment;
  my $cache_dir   = File::Spec->catdir($assetpack->out_dir, CACHE_DIR);
  my $map         = {};
  my @extra       = @{$self->browserify_args};
  my ($err, @modules);

  local $ENV{NODE_ENV} = $environment;
  mkdir $cache_dir or die "mkdir $cache_dir: $!" unless -d $cache_dir;
  $self->_node_module_path;
  $self->_find_node_modules($text, $path, $map);
  $self->{node_modules} = $map;

  # make external bundles from node_modules
  for my $module (grep {/^\w/} sort keys %$map) {
    my @external = map { -x => $_ } grep { $_ ne $module } keys %$map;
    push @modules, $self->_outfile($assetpack, "$module-$environment.js");
    next if -e $modules[-1] and (stat _)[9] >= (stat $map->{$module})[9];
    make_path(dirname $modules[-1]);
    $self->_run([$self->executable, @extra, @external, -r => $module, -o => $modules[-1]], undef, undef, \$err);
  }

  if (!length $err) {

    # make application bundle which reference external bundles
    push @extra, map { -x => $_ } grep {/^\w/} sort keys %$map;
    $self->_run([$self->executable, @extra, -e => $path], undef, $text, \$err);
  }
  if (length $err) {
    $self->_make_js_error($err, $text);
  }
  elsif (length $$text) {

    # bundle application and external bundles
    $$text = join "\n", (map { Mojo::Util::slurp($_) } @modules), $$text;
    $self->_minify($text, $path) if $assetpack->minify;
  }

  return $self;
}

sub _executable {
  my ($self, $name) = @_;
  my $paths = $self->{node_module_path} || $self->_node_module_path;

  for my $p (@$paths) {
    my $local = Cwd::abs_path(File::Spec->catfile($p, '.bin', $name));
    return $local if $local and -e $local;
  }

  return File::Which::which($name);
}

sub _find_node_modules {
  my ($self, $text, $path, $uniq) = @_;

  while ($$text =~ m!\brequire\s*\(\s*(["'])(.+?)\1\s*\)\s*!g) {
    my $module = $2;
    warn "[Browserify] require($module) from $path\n" if DEBUG;
    next if $uniq->{$module};
    $module =~ /^\w/
      ? $self->_follow_system_node_module($module, $path, $uniq)
      : $self->_follow_relative_node_module($module, $path, $uniq);
  }

  return keys %$uniq;
}

sub _follow_relative_node_module {
  my ($self, $module, $path, $uniq) = @_;
  my $base = $module;

  unless (File::Spec->file_name_is_absolute($base)) {
    $base = File::Spec->catfile(dirname($path), $module);
  }

  for my $ext ("", map {".$_"} @{$self->extensions}) {
    my $file = File::Spec->catfile(split '/', "$base$ext");
    return if $uniq->{"$module$ext"};
    next unless -f $file;
    $uniq->{"$module$ext"} = $file;
    my $js = Mojo::Util::slurp($file);
    return $self->_find_node_modules(\$js, $file, $uniq);
  }

  die "Could not find JavaScript module '$module'";
}

sub _follow_system_node_module {
  my ($self, $module, $path, $uniq) = @_;
  my $p;

  for my $prefix (@{$self->{node_module_path}}) {
    return $uniq->{$module} = $p if -e ($p = File::Spec->catfile($prefix, $module, 'package.json'));
    return $uniq->{$module} = $p if -e ($p = File::Spec->catfile($prefix, $module, 'index.js'));
    return $uniq->{$module} = $p if -e ($p = File::Spec->catfile($prefix, "$module.js"));
  }

  die "Could not find JavaScript module '$module' in @{$self->{node_module_path}}";
}

sub _minify {
  my ($self, $text, $path) = @_;
  my $uglifyjs = $self->_executable('uglifyjs');
  my $err      = '';

  if ($uglifyjs) {
    $self->_run([$uglifyjs, qw( -m -c  )], $text, $text, \$err);
  }
  else {
    require JavaScript::Minifier::XS;
    $$text = JavaScript::Minifier::XS::minify($$text);
    $err = 'JavaScript::Minifier::XS failed' unless $$text;
  }

  if (length $err) {
    $self->_make_js_error($err, $text);
  }
}

sub _node_module_path {
  my $self = shift;
  my @cwd  = File::Spec->splitdir(Cwd::getcwd);
  my @path;

  do {
    my $p = File::Spec->catdir(@cwd, 'node_modules');
    pop @cwd;
    push @path, $p if -d $p;
  } while (@cwd);

  warn "[Browserify] node_module_path=[@path]\n" if DEBUG;
  return $self->{node_module_path} = \@path;
}

sub _outfile {
  my ($self, $assetpack, $name) = @_;
  my $path = $assetpack->{static}->file(File::Spec->catfile(CACHE_DIR, $name));

  return $path if $path and -e $path;
  return File::Spec->catfile($assetpack->out_dir, CACHE_DIR, $name);
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
