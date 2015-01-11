package Mojolicious::Plugin::AssetPack::Preprocessor::Browserify;

=head1 NAME

Mojolicious::Plugin::AssetPack::Preprocessor::Browserify - Preprocessor using browserify components

=head1 SYNOPSIS

  use Mojolicious::Lite;

  plugin "AssetPack";

  app->asset->preprocessor(
    Browserify => {
      extensions => [qw( js jsx )], # default is "js"
      transformers => {reactify => {}}
    }
  );

=head1 DESCRIPTION

L<Mojolicious::Plugin::AssetPack::Preprocessor::Browserify> is a JavaScript
preprocessor which use L<browserify|http://browserify.org/> to do the heavy
lifting. Browserify allow you to C<require> JavaScript modules the same way
as you require Perl modules. This is very convenient, since it will isolate
your code and make it modular.

Example JavaScript module, in the shape of a React component:

  // load the node module "react"
  var React = require('react');

  // load a module from the same directory as the current file
  var Storage = require('./storage');

  // module.exports is the return value from require()
  module.exports = React.createClass({
    getInitialState: function() {
      return { name: Storage.get("name") };
    },
    render: function() {
      return <div>{this.state.name}</div>;
    }
  });

The above code is not valid JavaScript, but will be converted using a custom
L<transformer|/transformers>:

  app->asset->preprocessor(
    Browserify => {
      transformers => {reactify => {}}
    }
  );

In addition to L<reactify|https://www.npmjs.com/package/reactify>, there
are L<coffeeify|https://www.npmjs.com/package/coffeeify> and
L<a bunch|https://github.com/substack/node-browserify/wiki/list-of-transforms>
of others.

=head2 Auto install

C<require()> statements that point to "system modules" will be automatically
installed, unless already available.

  require("react");    // system module
  require("./custom"); // not a system module

This feauture is EXPERIMENTAL. L<Feedback wanted|https://github.com/jhthorsen/mojolicious-plugin-assetpack/issues>.

Example:

  # Run this in the root directory of your project
  $ npm install reactify

=head2 Minifying

Minifying is done using L<uglifyjs|https://www.npmjs.com/package/uglify-js>.
This application is an excellent tool, which does a whole lot more than
just making private variable names shorter.

=head2 Watch for changes

This module will watch the code you are working on and only recompile
the parts that change. This is the same feature that
L<watchify|https://www.npmjs.org/package/watchify> provides.

=head2 React with addons

Mixing libraries where some require "react" and other require "react/adddons"
will probably create an invalid bundle. The problem is that "react/adddons"
contain react+addons, which will 1) result in a huge bundle 2) fail in the
browser since you can't load the react library twice.

You can fix it with these steps:

=over 4

=item * Step 1

Make sure your main application file require C<react/adddons>:

  var React = require("react/adddons");

=item * Step 2

Install L<through2|https://www.npmjs.com/package/through2> and define your own
transformer in a file C<react-aliasify.js>:

  var through = require('through2');
  module.exports = function(file) {
    return through(function(buf, enc, next) {
      this.push(buf.toString('utf8').replace(/\brequire\s*\(.react.\)/g, "require('react/addons')"));
      next();
    });
  };

=item * Step 3

Add your custom transformer to AssetPack config:

  app->asset->preprocessor(
    Browserify => {
      transformers => {
        app->home->rel_file("react-aliasify.js") => {},
        reactify => {}
      ]
    }
  );

=item * Step 4

You're done! Now all your JavaScript libraries will require "react/addons"
instead of "react".

=back

=head1 SEE ALSO

=over 4

=item * L<http://browserify.org/>

Main homepage for browserify.

=item * L<https://www.npmjs.org/>

"CPAN" for JavaScript.

=item * L<commonjs|http://nodejs.org/docs/latest/api/modules.html#modules_modules>

How C<require()> works in JavaScript.

=back

=cut

use Mojo::Base 'Mojolicious::Plugin::AssetPack::Preprocessor';
use Mojo::JSON ();
use Mojo::Util;
use Cwd ();
use File::Basename qw( basename dirname );
use File::Path 'make_path';
use File::Spec::Functions 'catfile';
use File::Which ();
use constant DEBUG => $ENV{MOJO_ASSETPACK_DEBUG} || 0;

BEGIN {
  (eval 'require JSON::XS;1' ? 'JSON::XS' : 'Mojo::JSON')->import(qw( decode_json encode_json ));
}

=head1 ATTRIBUTES

=head2 executable

  $path = $self->executable;

Holds the path to "node" which is required to run the node based code.

=head2 npm_executable

  $path = $self->npm_executable;

Holds the path to the L<npm|https://www.npmjs.org/> executable which is used
to install node modules which is found when scanning for C<require()>
statements. Set this attribute to C<undef> to disable automatic installation
to C<node_modules> directory.

=head2 transformers

  $hash = $self->transformers;
  $self = $self->transformers({reactify => {}});

A hash of L<transformers|https://github.com/substack/node-browserify/wiki/list-of-transforms>
passed on to C<module-deps>. The keys are either a npm package name or a path
to the transformer.

TODO: The values should be options for the transformer.

=cut

has executable => sub { File::Which::which('nodejs') || File::Which::which('node') };
has npm_executable => sub { File::Which::which('npm') };
has transformers   => sub { {} };

has _node_module_paths => sub {
  my $self = shift;
  my @cwd  = File::Spec->splitdir(Cwd::getcwd);
  my @path;

  do {
    my $p = File::Spec->catdir(@cwd, 'node_modules');
    pop @cwd;
    push @path, $p if -d $p;
  } while @cwd;

  @path = (File::Spec->catdir($self->cwd, 'node_modules')) unless @path;
  push @path, split /:/, ($ENV{NODE_PATH} || '');
  warn "[Browserify] node_module_path=[@path]\n" if DEBUG;
  return \@path;
};

=head1 METHODS

=head2 can_process

  $bool = $self->can_process;

Returns true if L</executable> exists.

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

  local $self->{skip_system_node_module_scan} = 1;
  $self->_set_node_module_paths;    # make sure we have a clean path list on each run
  $self->_find_node_modules($text, $path, $map);
  Mojo::Util::md5_sum($$text, join '', map { Mojo::Util::slurp($map->{$_}) } sort grep { !/^\w/ } keys %$map);
}

=head2 process

Used to process the JavaScript using C<module-deps> and C<browser-pack>.

=cut

sub process {
  my ($self, $assetpack, $text, $path) = @_;
  my %transformers = %{$self->transformers};
  my $cache_path   = catfile(dirname($path), sprintf '.%s.cache', basename $path);
  my $cache        = -r $cache_path ? decode_json(Mojo::Util::slurp $cache_path) : {};
  my ($err, @cached);

  local $ENV{NODE_ENV} = $ENV{NODE_ENV} || $assetpack->{mode};

  for my $file (keys %$cache) {
    my @stat = stat $file;
    delete $cache->{$file} unless @stat;
    push @cached, $file if @stat and $cache->{$file}{mtime} == $stat[9];
  }

  if ($assetpack->minify) {
    $transformers{uglifyify} ||= {};
  }

  local $ENV{ASSETPACK_CACHED} = join ':', @cached;
  local $ENV{ASSETPACK_TRANSFORMERS} = encode_json(\%transformers);
  warn "[Browserify] ASSETPACK_TRANSFORMERS=$ENV{ASSETPACK_TRANSFORMERS}\n" if DEBUG;
  warn "[Browserify] NODE_ENV=$ENV{NODE_ENV}\n"                             if DEBUG;

  $self->_install_node_module($_) for qw( browser-pack module-deps JSONStream );
  $self->_install_node_module($_) for keys %transformers;
  $self->_find_node_modules($text, $path, {});    # install node deps
  $self->_run([$self->executable, catfile(dirname(__FILE__), 'module-deps.js'), $path], undef, $text, \$err);
  $self->_apply_cache($cache, $text, $cache_path) unless $err;
  $self->_run([$self->executable, $self->_node_module_path(qw( .bin browser-pack))], $text, $text, \$err) unless $err;
  $self->_make_js_error($err, $text) if $err;
}

sub _apply_cache {
  my ($self, $cache, $text, $cache_path) = @_;
  my $module_deps = decode_json $$text;

  for my $item (@$module_deps) {
    next unless $item->{source};
    $item->{mtime} = (stat $item->{file})[9];
    delete $item->{id} if $item->{file} eq $item->{id};
    $cache->{delete($item->{file})} = $item;
  }

  $$text = encode_json(
    [
      map {
        my $item = $cache->{$_};
        +{%$item, file => $_, id => $item->{id} || $_};
      } sort keys %$cache
    ]
  );

  Mojo::Util::spurt(encode_json($cache), $cache_path);
  warn "[Browserify] Wrote cache $cache_path\n" if DEBUG;
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
    $base = catfile(dirname($path), $module);
  }

  for my $ext ('', '.js', '.jsx', '.coffee') {
    my $file = catfile(split '/', "$base$ext");
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

  return $uniq->{$module} = 1 if $self->{skip_system_node_module_scan};
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

  # react/addons should be installed as react
  $module =~ s!/.*!!;

  local ($?, $!);
  return undef unless $self->npm_executable;
  return $self if $self->_node_module_path($module);
  return undef unless -w $self->cwd;
  warn "[Browserify] npm install $module\n" if DEBUG;
  require Mojolicious::Plugin::AssetPack::Preprocessors;
  my $cwd = Mojolicious::Plugin::AssetPack::Preprocessors::CWD->new($self->cwd);
  system $self->npm_executable, install => $module;
  die "Failed to run 'npm install $module': $?" if $?;
  return $self;
}

sub _node_module_path {
  my $self = shift;

  for my $path (@{$self->_node_module_paths}) {
    my $local = Cwd::abs_path(catfile($path, @_));
    return $local if $local and -e $local;
  }

  return;
}

sub _set_node_module_paths {
  delete $_[0]->{_node_module_paths};
  $_[0]->_node_module_paths;
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
