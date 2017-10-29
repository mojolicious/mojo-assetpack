package Mojolicious::Plugin::AssetPack::Pipe::RollupJs;
use Mojo::Base 'Mojolicious::Plugin::AssetPack::Pipe';

use Mojo::File qw(path tempfile);
use Mojo::Loader;
use Mojolicious::Plugin::AssetPack::Util qw(diag $CWD DEBUG);

has external => sub { [] };
has globals  => sub { [] };
has modules  => sub { [] };
has plugins  => sub {
  my $self    = shift;
  my @plugins = qw(rollup-plugin-node-resolve rollup-plugin-commonjs);
  push @plugins, 'rollup-plugin-uglify' if $self->assetpack->minify;
  return \@plugins;
};

has _rollupjs => sub {
  my $self = shift;
  my $bin = Mojo::Loader::data_section(__PACKAGE__, 'rollup.js');
  my (@import, @plugins);

  for my $plugin (@{$self->plugins}) {
    my $func = "plugin_$plugin";
    $func =~ s!\W!_!g;
    push @import,  "var $func = require('$plugin');\n";
    push @plugins, "$func()";
  }

  $bin =~ s!__PLUGINS__!{join '', @import}!e;
  $bin =~ s!__PLUGINS__!{join ',', @plugins}!e;

  if (DEBUG > 2) {
    $self->{_rollupjs_src} = path(File::Spec->tmpdir, 'assetpack-rollup.js');
    diag "[RollupJs] Keeping $self->{_rollupjs_src} around.";
  }
  else {
    $self->{_rollupjs_src} = tempfile(SUFFIX => '.js');
  }

  $self->{_rollupjs_src}->spurt($bin);

  return [$self->_find_app([qw(nodejs node)]), $self->{_rollupjs_src}->realpath];
};

sub process {
  my ($self, $assets) = @_;
  my $minify = $self->assetpack->minify;
  my $store  = $self->assetpack->store;
  my $file;

  $assets->each(
    sub {
      my ($asset, $index) = @_;
      my $attrs = $asset->TO_JSON;
      return unless $asset->format eq 'js';
      return unless $asset->path and -r $asset->path;
      return unless $asset->content =~ /\bimport\s.*\bfrom\b/s;

      $attrs->{key}      = 'rollup';
      $attrs->{minified} = $minify;
      return $asset->content($file)->FROM_JSON($attrs) if $file = $store->load($attrs);

      local $CWD            = $self->app->home->to_string;
      local $ENV{NODE_ENV}  = $self->app->mode;
      local $ENV{NODE_PATH} = $self->app->home->rel_file('node_modules');
      local $ENV{ROLLUP_EXTERNAL} = join ',', @{$self->external};
      local $ENV{ROLLUP_GLOBALS}  = join ',', @{$self->globals};
      local $ENV{ROLLUP_SOURCEMAP} = $self->app->mode eq 'development' ? 1 : 0
        if 0;    # TODO

      $self->_install_node_modules('rollup', @{$self->modules}, @{$self->plugins})
        unless $self->{installed}++;
      $self->run([@{$self->_rollupjs}, $asset->path, _module_name($asset->name)],
        undef, \my $js);
      $asset->content($store->save(\$js, $attrs))->FROM_JSON($attrs);
    }
  );
}

sub _module_name { local $_ = $_[0]; s!\W!_!g; lcfirst(Mojo::Util::camelize($_)) }

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::AssetPack::Pipe::RollupJs - Use Rollup.js module bundler

=head1 SYNOPSIS

  use Mojolicious::Lite;
  plugin AssetPack => {pipes => [qw(RollupJs)]};

=head1 DESCRIPTION

Rollup is a module bundler for JavaScript which compiles small pieces of code
into something larger and more complex, such as a library or application.

See L<https://rollupjs.org/> for more details.

=head1 ATTRIBUTES

=head2 external

  $array_ref = $self->external;
  $self = $self->external(["vue"]);

Comma-separate list of module IDs to exclude.

=head2 globals

  $array_ref = $self->globals;
  $self = $self->globals(["vue"]);

Comma-separate list of `module ID:Global` pairs. Any module IDs defined here
are added to L</external>.

=head2 modules

  $array_ref = $self->modules;
  $self = $self->modules(["vue"]);

List of NPM modules that the JavaScript application depends on.

=head2 plugins

  $array_ref = $self->plugins;
  $self = $self->plugins(["rollup-plugin-vue", "rollup-plugin-uglify"]);

List of NPM modules that should be loaded by Rollup.js.

=head1 METHODS

=head2 process

See L<Mojolicious::Plugin::AssetPack::Pipe/process>.

=head1 SEE ALSO

L<Mojolicious::Plugin::AssetPack>.

=cut

__DATA__
@@ rollup.js
#!/usr/bin/env node
'use strict'

const globals = process.env.ROLLUP_GLOBALS.split(",");
const external = process.env.ROLLUP_EXTERNAL.split(",");
const rollup = require('rollup');
const stdout = process.stdout;

__PLUGINS__

globals.forEach(function(g) { external.push(g.split(":")[0]) });

const inputOptions = {
  input: process.argv[2],
  external: function(name) { return external.indexOf(name) != -1 },
  plugins: [__PLUGINS__]
};

const outputOptions = {
  format: "iife",
  globals: globals,
  name: process.argv[3],
  sourcemap: "inline",
  // TODO
  banner: process.env.ROLLUP_BANNER,
  footer: process.env.ROLLUP_FOOTER,
  intro: process.env.ROLLUP_INTRO,
  outro: process.env.ROLLUP_OUTRO
};

async function build() {
  const bundle = await rollup.rollup(inputOptions);
  const { code, map } = await bundle.generate(outputOptions);
  stdout.write(code);
  if (process.env.ROLLUP_SOURCEMAP) stdout.write("\n//# sourceMappingURL=" + map + "\n");
}

build();
