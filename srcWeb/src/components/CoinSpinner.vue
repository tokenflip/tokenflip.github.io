<template>
  <div class="icon-card">

    <div v-if="showSelectedSide && !isSpinning" class="icon-card__side " v-bind:class="{'waiting-start': waitingForStart}">
      <img v-if="selectedSide === 'obverse'" src="../assets/obverse.png" alt="icon" class="icon--image" />
      <img v-else-if="selectedSide === 'reverse'" src="../assets/reverse.png" alt="icon" class="icon--image" />
    </div>

    <div id="obverse" ref="obverse" class="icon-card__side icon-card__side--front" v-bind:class="{'rotating': spinning,
            'anim-front': obAnimFront, 'anim-back': obAnimBack, 
            'card-back': obCardBack, 'hidden': showSelectedSide}">
      <img src="../assets/obverse.png" alt="icon" class="icon--image" />
    </div>

    <div id="reverse" ref="reverse" class="icon-card__side" v-bind:class="{'rotating-side': spinning,
            'anim-front': reAnimFront, 'icon-card__side--back': rotateReverse,
            'anim-back': reAnimBack, 'card-front': reCardFront,
            'hidden': showSelectedSide}">
      <img src="../assets/reverse.png" alt="icon" class="icon--image" />
    </div>

  </div>
</template>

<script>

  var timestampStarted = null
  var fullFlipTime = '0.5s'
  var flipSlowdownTime = '1s'

  export default {
    data() {
      return {
        selectedSide: 'obverse',
        spinning: false,
        showSelectedSide: true,
        waitingForStart: false,
        obAnimFront: false,
        obAnimBack: false,
        obCardBack: false,
        reAnimFront: false,
        reAnimBack: false,
        reCardFront: false,
        rotateReverse: true
      }
    },
    computed: {
      isSpinning() {
        return this.spinning
      }
    },
    methods: {
      sideChanged(newSide) {
        this.showSelectedSide = true
        this.selectedSide = newSide
      },
      startSpinning() {
        if (this.spinning)
          return

        timestampStarted = Date.now();
        this.showSelectedSide = false
        this.obAnimFront = false
        this.obAnimBack = false
        this.reAnimFront = false
        this.reAnimBack = false
        this.obCardBack = false
        this.reCardFront = false
        this.rotateReverse = true
        this.waitingForStart = false
        this.spinning = true
      },
      endSpinning(side) {
        if (!this.spinning)
          return

        let animationDuration = 500;
        let timeSpinning = (Date.now() - timestampStarted);
        let flipsEvaluated = timeSpinning / animationDuration;
        let shouldFinishFlip = (Math.ceil(flipsEvaluated) - flipsEvaluated);
        let whichFlipIsLast = flipsEvaluated + shouldFinishFlip;
        let timeout = 0;

        if (side === "obverse") {
          timeout = (whichFlipIsLast * animationDuration) - timeSpinning;
          setTimeout(() => {
            this.reAnimFront = true
            this.obAnimBack = true
            this.spinning = false
          }, timeout);
        } else if (side === "reverse") {
          timeout = (whichFlipIsLast * animationDuration) - timeSpinning + (animationDuration / 2);
          setTimeout(() => {
            this.obAnimFront = true
            this.reAnimBack = true
            this.rotateReverse = false
            this.spinning = false
            setTimeout(() => {
              this.obCardBack = true
              this.reCardFront = true
            }, 1000);
          }, timeout);
        }
      },
      waitForSpinStart() {
        this.showSelectedSide = true
        this.obAnimFront = false
        this.obAnimBack = false
        this.obCardBack = false
        this.reAnimFront = false
        this.reAnimBack = false
        this.reCardFront = false
        this.waitingForStart = true
      }
    },
    mounted() {
      let element = this.$refs['obverse']
      element.style.setProperty('--anim-full-spin-duration', fullFlipTime)
      element.style.setProperty('--anim-slowdown-time', flipSlowdownTime)
      element = this.$refs['reverse']
      element.style.setProperty('--anim-full-spin-duration', fullFlipTime)
      element.style.setProperty('--anim-slowdown-time', flipSlowdownTime)
    }
  }
</script>

<style>
  .hidden {
    visibility: hidden;
  }

  .card {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    width: 500px;
    border: 1px solid rgba(149, 73, 200, 0.5);
    border-radius: 3px;
    text-align: center;
    box-shadow: 0 0.2rem 1.5rem rgba(0, 0, 0, 0.1);
  }

  .icon {
    position: relative;
  }

  .icon::after {
    visibility: hidden;
    display: block;
    font-size: 0;
    content: " ";
    clear: both;
    height: 0;
  }

  .icon--image {
    width: 20rem;
    height: 20rem;
  }

  .waiting-start {
    -webkit-animation: waiting-start var(--waiting-for-start-duration) infinite linear;
    animation: waiting-start 3s infinite linear;
  }

  .rotating {
    -webkit-animation: rotatingY var(--anim-full-spin-duration) infinite linear;
    animation: rotatingY var(--anim-full-spin-duration) infinite linear;
  }

  .rotating-side {
    -webkit-animation: rotatingY-side var(--anim-full-spin-duration) infinite linear;
    animation: rotatingY-side var(--anim-full-spin-duration) infinite linear;
  }

  .anim-front {
    animation: flipHeads var(--anim-slowdown-time) ease-out;
  }

  .anim-back {
    animation: flipTails var(--anim-slowdown-time) ease-out;
  }

  .card-front {
    -webkit-backface-visibility: visible !important;
    -moz-backface-visibility: visible !important;
    -ms-backface-visibility: visible !important;
    backface-visibility: visible !important;
  }

  .card-back {
    visibility: hidden;
  }

  .icon-card {
    position: relative;
    height: 20rem !important;
    width: 20rem !important;
  }

  .flip .icon-card {
    width: 200px;
    margin: 20px auto;
  }

  .icon-card::after {
    visibility: hidden;
    display: block;
    font-size: 0;
    content: " ";
    clear: both;
    height: 0;
  }

  .icon-card__side {
    transition: all .8s ease;
    position: absolute;
    top: 0;
    left: 0;
    float: left;
    -webkit-backface-visibility: hidden;
    -moz-backface-visibility: hidden;
    -ms-backface-visibility: hidden;
    backface-visibility: hidden;
    border-radius: 3px;
    overflow: hidden;
  }

  .icon-card__side--back {
    transform: rotateY(180deg);
  }

  @keyframes waiting-start {
    0% {
      transform: rotateY(0deg);
    }
    25% {
      transform: rotateY(-30deg);
    }
    50% {
      transform: rotateY(0deg);
    }
    75% {
      transform: rotateY(30deg);
    }
    100% {
      transform: rotateY(0deg);
    }
  }

  @keyframes rotatingY {
    from {
      transform: rotateY(0deg);
    }
    to {
      transform: rotateY(360deg);
    }
  }

  @keyframes rotatingY-side {
    from {
      transform: rotateY(180deg);
    }
    to {
      transform: rotateY(540deg);
    }
  }

  @keyframes flipHeads {
    from {
      transform: rotateY(540deg);
    }
    to {
      transform: rotateY(900deg);
    }
  }

  @keyframes flipTails {
    from {
      transform: rotateY(720deg);
    }
    to {
      transform: rotateY(1080deg);
    }
  }
</style>