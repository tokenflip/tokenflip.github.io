<script>
  export default {
    methods: {
      getFlipStatusString(statusIndex) {
        return statusIndex === '0' ? 'NotSet' :
          statusIndex === '1' ? 'Flipping' :
            statusIndex === '2' ? 'Won' :
              statusIndex === '3' ? 'Lost' : 'Refunded'
      }
    }
  }
</script>
