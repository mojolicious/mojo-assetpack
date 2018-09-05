package Mojolicious::Plugin::AssetPack::Pipe::RollupJs;
use Mojo::Base 'Mojolicious::Plugin::AssetPack::Pipe';

use Mojo::File qw(path tempfile);
use Mojo::JSON qw(encode_json false true);
use Mojo::Loader;
use Mojolicious::Plugin::AssetPack::Util qw(diag $CWD DEBUG);

has external => sub { [] };
has globals  => sub { {} };
has modules  => sub { [] };
has plugins  => sub {
  my $self = shift;
  my @plugins;
  push @plugins, ['rollup-plugin-node-resolve', 'resolve', {}];
  push @plugins, ['rollup-plugin-commonjs', 'commonjs', {sourceMap => true}];
  push @plugins, ['rollup-plugin-terser', '{terser}' => {}] if $self->assetpack->minify;
  return \@plugins;
};

has _rollupjs => sub {
  my $self = shift;
  my $bin = Mojo::Loader::data_section(__PACKAGE__, 'rollup.js');
  my (@import, @plugins);

  for (@{$self->plugins}) {
    my ($plugin, $import, $args) = @$_;
    my $func = $import;
    $func =~ s!\{\s*(.+)\s*\}!$1!;
    push @import, sprintf "const %s = %s;\n", $import,
      $import =~ m!^\s*\{! ? qq[require("$plugin")] : qq[_interopDefault(require("$plugin"))];
    push @plugins, sprintf '%s(%s)', $func, defined $args ? encode_json $args : '';
  }

  $bin =~ s!__EXTERNAL__!{encode_json $self->external}!e;
  $bin =~ s!__GLOBALS__!{encode_json $self->globals}!e;
  $bin =~ s!__SOURCEMAP__!{$self->app->mode eq 'development' ? 1 : 0}!e;
  $bin =~ s!__IMPORT__!{join '', @import}!e;
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

sub add_global {
  $_[0]->globals->{$_[1]} = $_[2];
  $_[0];
}

sub process {
  my ($self, $assets) = @_;
  my $minify = $self->assetpack->minify;
  my $store  = $self->assetpack->store;
  my $file;

  delete $self->{$_} for qw(_rollupjs _rollupjs_src);

  $assets->each(sub {
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

    $self->_install_node_modules('rollup', @{$self->modules}, map { $_->[0] } @{$self->plugins})
      unless $self->{installed}++;
    $self->run([@{$self->_rollupjs}, $asset->path, _module_name($asset->name)], undef, \my $js);
    $asset->content($store->save(\$js, $attrs))->FROM_JSON($attrs);
  });
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

  $hash_ref = $self->globals;
  $self = $self->globals({vue => "Vue"});

See L<https://rollupjs.org/guide/en#output-globals-g-globals>.

Any module IDs defined here are added to L</external>.

=head2 modules

  $array_ref = $self->modules;
  $self = $self->modules(["vue"]);

List of NPM modules that the JavaScript application depends on.

=head2 plugins

  $array_ref = $self->plugins;
  $self = $self->plugins([
            [$module_name, $import_statement, $import_function_args],
            ["rollup-plugin-vue", "VuePlugin"],
            ["rollup-plugin-node-resolve", "resolve", {}],
            ["rollup-plugin-commonjs", "commonjs", {sourceMap => false}],
          ]);

List of NPM modules that should be loaded by Rollup.js.

=head1 METHODS

=head2 add_global

  $self = $self->add_global($key => $value);
  $self = $self->add_global(qw(vue Vue));

Used to add a key/value pair to L</globals>.

=head2 process

See L<Mojolicious::Plugin::AssetPack::Pipe/process>.

=head1 SEE ALSO

L<Mojolicious::Plugin::AssetPack>.

=cut

__DATA__
@@ rollup.js
#!/usr/bin/env node
"use strict"

const globals = __GLOBALS__;
const external = __EXTERNAL__;
const rollup = require("rollup");
const stdout = process.stdout;

function _interopDefault(i) {
  return i && typeof i === "object" && "default" in i ? i["default"] : i;
}

__IMPORT__

Object.keys(globals).forEach(function(g) { external.push(g) });

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
  if (__SOURCEMAP__) stdout.write("\n//# sourceMappingURL=" + map + "\n");
}

build();
