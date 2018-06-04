<template>
  <div class="how-to-play">
    <el-button class="form-btn btn htp-button" type="text" @click="dialogVisible = true">How to play?</el-button>
    <el-dialog title="How to play?" :visible.sync="dialogVisible" :show-close="false">
      <div class="popup__content-box">
        <p class="popup__paragraph">You can win 2x more coins then buy coins using casual exchange, or lose all bet.
          <br>This game runs on Ethereum network,and random number oracle - Oraclize infrastructure with Wolframalpha service.
          <br>
          <a href="https://etherscan.io/address/0x1A9206CD9a4C59967ca728CA96b15287B2Fd4c7C" target="_blank">Contract address 0x1A9206CD9a4C59967ca728CA96b15287B2Fd4c7C</a>
          <br>
          <a href="https://github.com/tokenflip/tokenflip.github.io" target="_blank">Github</a>
        </p>
        <p class="popup__paragraph">To play this game you should use “Metamask” Extension or other ethereum network wallet friendly environment.
          <br>
        </p>
        <p class="popup__paragraph">
          <span>NOTE: this game is for learning purposes, not gambling!</span>
        </p>
        <br>
        <p class="popup__paragraph"><span class="popup__paragraph--title">How game is working:</span>
          <br> Playing with Token:
          <br> - Transaction is created to Token contract with bet
          <br> - Token contract allocates coins and allow CoinFlip contract to take coins.
          <br> - CoinFlip contract takes Coins and register Oraclize query for solution.
          <br> - Oraclize creates resolved transaction and submit __callback to CoinFlip contract.
          <br> - If user Win payout will be created if lost Game is over.

          <br>
          <br> Playing with ETH:
          <br> - CoinFlip contract calculates Token-ETH Bancor convertion Rate
          <br> - CoinFlip contract registers Oraclize query for solution.
          <br> - Oraclize creates resolved transaction and submit __callback to CoinFlip contract.
          <br> - If user Win payout will be created if lost Game is over.
        </p>

        <p class="popup__paragraph"><span class="popup__paragraph--title">Transaction fees:</span>
          <br> Recommend Gas limit: 600000
          <br> Gas price: choose optimal price from
          <a href="https://ethgasstation.info/ " target="_blank">ethgasstation</a>.
          <br> Bigger price you enter, faster coin will flip. In most cases price is 2 Gwei.
        </p>
        <p class="popup__paragraph"><span class="popup__paragraph--title">Game fees:</span>
          <br> This fee is used for Oraclize callbacks.
          <br> When you bet with AIX it is {{ web3.utils.fromWei(feeTokens).toString() }} AIX
          <br> When you bet with ETH it is {{ web3.utils.fromWei(feeETH).toString() }} ETH
        </p>
        <p> <span class="popup__paragraph--title">Game rules:</span>
          <br> Min amount {{ minBetETH.toString() }} ETH - Max {{ maxBetETH.toString() }} ETH
          <br> Token min amount {{ minBetAIX.toString() }} AIX - {{ maxBetAIX.toString() }} AIX
          <br>
          <br> Bet: Choose Token or ETH
          <br> Coin side: Choose Obverse (Ether sign) or Reverse (1) side.
          <br>
          <br> Prize Formula:
          <br> If token then prize = (bet - fee) * 2
          <br> If ETH then prize = (bet - fee) * [bancor price] * 2
          <br>
          <br> Coin Flipping time depends on:
          <br> - blockchain transaction execution time
          <br> - gas you provided for transactions
          <br> - oracle response transaction.
          <br> On normal conditions lt would take around 1 min.
          <br>
        </p>

        <br>
        <p class="popup__paragraph"><span class="popup__paragraph--title">Having troubles?</span>
          <br>
          <router-link :to="{ name: 'Troubleshoot' }">Troubleshoot</router-link>
        </p>

      </div>
      <div style="text-align: center">
        <el-button style="width: 200px;" class="form-btn btn htp-button" type="text" @click="dialogVisible = false">Close</el-button>
      </div>
    </el-dialog>

  </div>
</template>



<script>
  import Web3 from 'web3'
  import utils from '@/mixins/Utils.vue'
  import ContractMethods from '@/mixins/ContractMethodsMixin.vue'
  import config from '@/config.json'
  const web3 = window.web3 !== undefined ? new Web3(window.web3.currentProvider) : null


  export default {
    name: 'HowToPlay',
    mixins: [utils, ContractMethods],
    data() {
      return {
        dialogVisible: false,
        feeTokens: '-',
        feeETH: '-',
        FlipInstance: null,
        minBetETH: '-',
        maxBetETH: '-',
        minBetAIX: '-',
        maxBetAIX: '-',
      };
    },
    computed: {
      web3() {
        return web3
      },
      isWeb3Present() {
        return web3 !== null
      }
    },
    created() {
      if (this.isWeb3Present) {
        this.FlipInstance = new web3.eth.Contract(config.CoinFlipABI, config.FlipAddress)
      }

      this.getOracleFeeETH().then((fee) => {
        this.feeETH = fee
      })

      this.getOracleFeeAIX().then((fee) => {
        this.feeTokens = fee
      })

      this.setMinMaxValues()
    }
  }

</script>

<style scoped>
  a {
    word-wrap: break-word;
  }

  .popup__paragraph--title {
    color: #9549c8;
    font-weight: 600;
    font-size: 18px;
  }

  .popup__paragraph:not(:last-child) {
    margin-bottom: 2rem;
  }

</style>
