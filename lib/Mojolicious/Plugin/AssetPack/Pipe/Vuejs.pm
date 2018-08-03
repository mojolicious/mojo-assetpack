package Mojolicious::Plugin::AssetPack::Pipe::Vuejs;
use Mojo::Base 'Mojolicious::Plugin::AssetPack::Pipe';

sub process {
  my ($self, $assets) = @_;
  my $store = $self->assetpack->store;

  return $assets->each(sub {
    my ($asset, $index) = @_;
    return unless $asset->format eq 'vue';

    my $vue = sprintf 'Vue.component("%s", {', $asset->name;
    my ($script, $template);

    if ($asset->content =~ m!<script[^>]*>(.+)</script>!s) {
      $script = $1;
      $vue = "$1$vue" if $script =~ s!^(.*)\s?module\.exports\s*=\s*\{!!s;
      $script =~ s!\s*\}\s*;?\s*$!!s;
      $vue .= $script;
    }

    if ($asset->content =~ m!<template[^>]*>(.+)</template>!s) {
      $template = $1;
      $template =~ s!"!\\"!g;    # escape all double quotes
      $template =~ s!^\s*!!s;
      $template =~ s!\r?\n!\\n!g;
      $vue .= qq',\n' if $script;
      $vue .= qq'  template: "$template"';
    }

    $vue = Mojo::Util::encode('UTF-8', "(function(){$vue})})();");
    $asset->content($vue)->format('js');
  });
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::AssetPack::Pipe::Vuejs - Process .vue files

=head1 DESCRIPTION

This modules is EXPERIMENTAL and based on homebrewed regexes instead of running
the code through an external nodejs binary!

This pipe could get pulled completely from the
L<Mojolicious::Plugin::AssetPack> distribution if the problem is too hard to
solve.

=head1 SYNOPSIS

Currently only C<script> and C<template> is supported. C<style> is not yet
supported.

Here is an example C<.vue> file:

  <template>
    <h1 :id="id">Example</h1>
    <button @click="toggle" :disabled="loading">{{loading ? "loading" : "click me!"}}</button>
  </template>

  <script>
  var initial = false;
  module.exports = {
    data: function() {
      return {id: id, loading: initial}
    },
    methods: {
      toggle: function() {
        this.loading = !this.loading;
      }
    }
  };
  </script>

The vuejs file above produces this output:

  (function(){
  var initial = false;
  Vue.component("example", {
    data: function() {
      return {id: id, loading: initial}
    },
    methods: {
      toggle: function() {
        this.loading = !this.loading;
      }
    },
  template: "
    Example
    {{loading ? \"loading\" : \"click me!\"}}
  "}))();

=head1 METHODS

=head2 process

See L<Mojolicious::Plugin::AssetPack::Pipe/process>.

=head1 SEE ALSO

L<Mojolicious::Plugin::AssetPack>.

=cut
