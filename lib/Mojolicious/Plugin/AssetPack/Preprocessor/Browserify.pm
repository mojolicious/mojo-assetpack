package Mojolicious::Plugin::AssetPack::Preprocessor::Browserify;

=head1 NAME

Mojolicious::Plugin::AssetPack::Preprocessor::Browserify - Preprocessor using browserify

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Preprocessor::Browserify> is a JavaScript
preprocessor which use L<browserify|http://browserify.org/>.

Features:

=over 4

=item * Require

The main feature is that you can C<require()> JavaScript modules:

  var adder = require("adder");
  console.log(adder(1, 2));

See L<commonjs|http://nodejs.org/docs/latest/api/modules.html#modules_modules>
for more details.

=item * NPM modules

You can depend on L<npm|https://www.npmjs.org/> modules, which
allows reuse of code in your JavaScript code.

=item * Watch required modules

This module will watch the code you are working on and only recompile
the parts that change. This is the same feature that
L<watchify|https://www.npmjs.org/package/watchify> provides.

=item * Pre-processing

L<AssetPack|Mojolicious::Plugin::AssetPack> is already a preprocessor,
but you can also include node based preprocessors which allow you to
use modules such as L<React|http://facebook.github.io/react/>:

  var React = require("react");
  React.render(
    <h1>Hello, world!</h1>,
    document.getElementById('example')
  );

=back

=head1 SYNOPSIS

  use Mojolicious::Lite;

  plugin "AssetPack";

  app->asset->preprocessor(
    Browserify => {
      browserify_args => [-g => "reactify"],
      environment => app->mode, # default
      extensions => [qw( js jsx )], # default is "js"
    },
  ),

=cut

use Mojo::Base 'Mojolicious::Plugin::AssetPack::Preprocessor';
use Mojo::Util;
use Cwd ();
use File::Basename 'dirname';
use File::Path 'make_path';
use File::Spec;
use File::Which ();
use constant DEBUG => $ENV{MOJO_ASSETPACK_DEBUG} || 0;

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

Holds the path to the "browserify" executable. Defaults to just "browserify".
C<browserify> can also be found in C<./node_modules/.bin/browserify>, in the
current project directory.

=head2 npm_executable

  $path = $self->npm_executable;

Holds the path to the L<npm|https://www.npmjs.org/> executable which is used
to install node modules which is found when scanning for C<require()>
statements. Set this attribute to C<undef> to disable automatic installation
to C<node_modules> directory.

=cut

has browserify_args => sub { [] };
has environment     => sub { $ENV{MOJO_MODE} || $ENV{NODE_ENV} || 'development' };
has extensions      => sub { ['js'] };
has executable => sub { shift->_executable('browserify') || 'browserify' };
has npm_executable => sub { File::Which::which('npm') };

has _node_module_paths => sub {
  my $self = shift;
  my @cwd  = File::Spec->splitdir(Cwd::getcwd);
  my @path;

  do {
    my $p = File::Spec->catdir(@cwd, 'node_modules');
    pop @cwd;
    push @path, $p if -d $p;
  } while @cwd;

  warn "[Browserify] node_module_path=[@path]\n" if DEBUG;
  return \@path;
};

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

  delete $self->{_node_module_paths};
  $self->_find_node_modules($text, $path, $map);
  Mojo::Util::md5_sum($$text, join '', map { Mojo::Util::slurp($map->{$_}) } sort keys %$map);
}

=head2 process

Used to process the JavaScript using C<browserify>.

=cut

sub process {
  my ($self, $assetpack, $text, $path) = @_;
  my $environment = $self->environment;
  my $cache_dir   = $assetpack->out_dir;
  my $map         = {};
  my @extra       = @{$self->browserify_args};
  my ($err, @modules);

  local $ENV{NODE_ENV} = $environment;
  mkdir $cache_dir or die "mkdir $cache_dir: $!" unless -d $cache_dir;
  delete $self->{_node_module_paths};
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
  my $exe;

  $exe = $self->_node_module_path('.bin', $name);
  eval { $self->_install_node_module($name) } unless $exe;
  $exe = $self->_node_module_path('.bin', $name);
  return $exe || File::Which::which($name);
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

  $self->_install_node_module($module);

  for my $prefix (@{$self->_node_module_paths}) {
    return $uniq->{$module} = $p if -e ($p = File::Spec->catfile($prefix, $module, 'package.json'));
    return $uniq->{$module} = $p if -e ($p = File::Spec->catfile($prefix, $module, 'index.js'));
    return $uniq->{$module} = $p if -e ($p = File::Spec->catfile($prefix, "$module.js"));
  }

  die "Could not find JavaScript module '$module' in @{$self->_node_module_paths}";
}

sub _install_node_module {
  my ($self, $module) = @_;
  my $cwd = Cwd::getcwd;

  local ($?, $!);
  return unless $self->npm_executable;
  return $self if -d File::Spec->catdir($cwd, 'node_modules', $module);
  system $self->npm_executable, install => $module;
  die "Failed to run 'npm install $module': $?" if $?;
  return $self;
}

sub _minify {
  my ($self, $text, $path) = @_;
  my $uglifyjs = $self->_executable('uglifyjs');
  my $err      = '';

  $self->_run([$uglifyjs, qw( -m -c  )], $text, $text, \$err);

  if (length $err) {
    $self->_make_js_error($err, $text);
  }
}

sub _node_module_path {
  my $self = shift;

  for my $path (@{$self->_node_module_paths}) {
    my $local = Cwd::abs_path(File::Spec->catfile($path, @_));
    return $local if $local and -e $local;
  }

  return;
}

sub _outfile {
  my ($self, $assetpack, $name) = @_;
  my $path = $assetpack->{static}->file($name);

  return $path if $path and -e $path;
  return File::Spec->catfile($assetpack->out_dir, $name);
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
