<template>
  <div id="app">
    <transition name="slideUp">
      <router-view class="aig-view"></router-view>
    </transition>
  </div>
</template>

<script>

  export default {
    name: 'App',
    components: {
    }
  }

</script>

<style>
  #app {
    font-family: 'Raleway', sans-serif;
    color: #4f3b8e;
    -webkit-font-smoothing: antialiased;
    -moz-osx-font-smoothing: grayscale;
  }
</style>
