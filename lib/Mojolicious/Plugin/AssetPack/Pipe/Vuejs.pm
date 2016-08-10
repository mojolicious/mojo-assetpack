package Mojolicious::Plugin::AssetPack::Pipe::Vuejs;
use Mojo::Base 'Mojolicious::Plugin::AssetPack::Pipe';
use Mojo::DOM;

sub process {
  my ($self, $assets) = @_;
  my $store = $self->assetpack->store;

  return $assets->each(
    sub {
      my ($asset, $index) = @_;
      return unless $asset->format eq 'vue';

      my $vue = Mojo::DOM->new($asset->content);
      my $js = sprintf 'Vue.component("%s", {', $asset->name;
      my %elem;

      $vue->children->each(sub { $elem{$_->tag} = $_->content; });

      if ($elem{script}) {
        $elem{script} =~ s!^(.*)\s?module\.exports\s*=\s*\{!!s;
        $js = "$1$js" if $1;
        $elem{script} =~ s!\s*\}\s*;?\s*$!!s;
        $js .= $elem{script};
      }
      if ($elem{template}) {
        $elem{template} =~ s!"!\\"!g;    # escape all double quotes
        $elem{template} =~ s!^\s*!!s;
        $elem{template} =~ s!\r?\n!\\n!g;
        $js .= qq',\n' if $elem{script};
        $js .= qq'  template: "$elem{template}"';
      }

      $js = Mojo::Util::encode('UTF-8', "(function(){$js})})();");
      $asset->content($js)->format('js');
    }
  );
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
