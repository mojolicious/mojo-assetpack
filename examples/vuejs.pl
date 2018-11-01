#!/usr/bin/env perl
use Mojolicious::Lite;

plugin AssetPack => {pipes => ['Vuejs', 'JavaScript']};
app->asset->process('app.js' => 'some-component.vue', 'app.js');

get '/' => 'index';

app->start;

__DATA__
@@ index.html.ep
<!DOCTYPE html>
<html>
  <head>
  </head>
  <body>
    <div id="vue_app"><some-component/></div>
    <script src="https://cdn.jsdelivr.net/npm/vue/dist/vue.js"></script>
    %= asset 'app.js';
  </body>
</html>

@@ app.js
var app = new Vue({
  el: '#vue_app'
})

@@ some-component.vue
<template>
  <span :class="foo == 'unknown' ? 'text-muted' : ''">Bar</span>
</template>

<script>
module.exports = {
  data: function() {
    return {foo: "nope"};
  }
};
</script>
