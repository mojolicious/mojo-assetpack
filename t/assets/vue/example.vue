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
