// The Vue build version to load with the `import` command
// (runtime-only or standalone) has been set in webpack.base.conf with an alias.
import Vue from 'vue'
import App from './App'
import Web3 from 'web3'
import ElementUi from 'element-ui'
import locale from 'element-ui/lib/locale/lang/en'
import router from '@/router'

import 'element-ui/lib/theme-chalk/index.css'
import '@/css/CoinFlip.css'

Vue.config.productionTip = false
Vue.use(ElementUi, { locale })
Vue.filter('truncate', function(text, stop, clamp) {
  return text.slice(0, stop) + (stop < text.length ? clamp || '...' : '')
})

/* eslint-disable no-new */
new Vue({
  router,
  el: '#app',
  components: {
    App
  },
  template: '<App/>'
})
