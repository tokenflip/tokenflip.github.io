<template>
  <div class="container flip">
    <h2>How to troubleshoot?</h2>
    <p>If you want to check your transaction status - if it has already been mined, in which block it was mined in or any other
      information about the transaction, you can go to
      <a :href="etherscanLink">Etherscan</a>
      and enter your transaction transaction hash.
    </p>
    </br>
    <p>If you want to see your flip information, enter your
      <span class="bold">Flip ID</span> below:
    </p>
    <el-form :rules="formRules" label-position="right" @:inline="true" ref="form" :model="form">
      <el-form-item prop="flipId">
        <el-input v-model="form.flipId" placeholder="Enter Flip ID"></el-input>
      </el-form-item>
      <button @click.prevent="submitForm" class="btn submit-button">Get Flip Info</button>
    </el-form>

    <el-row class="info-container" v-if="flipInfo">
      <el-row>
        <span>Your public address: </span>
        <span class="bold">{{ web3.eth.defaultAccount }}</span>
      </el-row>
      <el-row>
        <span>Flip ID: </span>
        <el-popover placement="top" trigger="click">{{ cachedFlipId }}
          <span class="bold underline" slot="reference">{{ cachedFlipId.substring(0, 20) }}...</span>
        </el-popover>
      </el-row>
      <el-row>
        <span>Bet (Token): </span>
        <span class="bold">{{ flipInfo.betAIX }}</span>
      </el-row>
      <el-row>
        <span>Bet (ETH): </span>
        <span class="bold">{{ flipInfo.betETH }}</span>
      </el-row>
      <el-row>
        <span>Status: </span>
        <span class="bold">{{ flipInfo.flipStatus }}</span>
      </el-row>
      <el-row>
        <span>Completed: </span>
        <span class="bold">{{ flipInfo.completed }}</span>
      </el-row>
      <el-row v-if="flipInfo.winAix !== 0">
        <span>Won: </span>
        <span class="bold"> {{ flipInfo.winAIX }} Tokens </span>
      </el-row>
    </el-row>
    <el-row v-if="flipInfo && !flipInfo.completed && showRefund && !refundStarted" class="info-container">
      <p class="text">Looks like your coin flip has not resolved yet. Press the button bellow to get the refund.</p>
      <el-button @click="refund" class="btn">Refund</el-button>
    </el-row>
    <el-row v-if="refundStarted && !refunded" class="info-container">
      <p class="green-text">
        Your refund has started. You can check out refund transaction
        <a :href="etherscanLink + 'tx/' + refundTxHash "> here</a>
      </p>
    </el-row>
    <el-row v-if="refunded" class="info-container">
      <p class="green-text">
        Your flip has been refunded
      </p>
    </el-row>
    <el-row v-if="flipInfo && flipInfo.flipStatus === 'Won'" class="info-container">
      <p class="green-text">
        You won
      </p>
    </el-row>
    <el-row v-if="flipInfo && flipInfo.flipStatus === 'Lost'" class="info-container">
      <p class="red-text">
        You lost
      </p>
    </el-row>
    <router-link class="btn" :to="{ path: '/' }">Back</router-link>
  </div>
</template>

<script>
  import Web3 from 'web3'
  const web3 = window.web3 !== undefined ? new Web3(window.web3.currentProvider) : null
  import config from '@/config.json'
  import GetFlipStatusMixin from '@/mixins/GetFlipStatusMixin.vue'

  export default {
    name: 'Troubleshoot',
    mixins: [GetFlipStatusMixin],
    data() {
      return {
        form: {
          flipId: ''
        },
        FlipInstance: null,
        flipInfo: null,
        cachedFlipId: '',
        showRefund: false,
        refundStarted: false,
        refunded: false,
        refundTxHash: '',
        flipRefundInfo: '',
        formRules: {
          flipId: [{
            required: true,
            message: "Flip ID is required",
            trigger: 'blur'
          },
          {
            min: 66,
            max: 66,
            message: "Flip ID has to be 66 characters long",
            trigger: 'blur'
          }
          ]
        }
      }
    },
    computed: {
      web3() {
        return web3
      },
      isWeb3Present() {
        return web3 !== null
      },
      etherscanLink() {
        return config.EtherscanLink
      }
    },
    methods: {
      submitForm() {
        this.$refs['form'].validate(valid => {
          if (valid) this.getFlipInfo()
          else return false
        })
      },
      getFlipInfo(flipID) {
        this.showRefund = true
        this.refundStarted = false
        this.refunded = false
        const id = flipID || this.form.flipId
        this.cachedFlipId = id
        this.FlipInstance.methods
          .flips(id)
          .call({
            from: this.defaultAccount
          })
          .then((response, error) => {
            this.flipInfo = response
            this.flipInfo.flipStatus = this.getFlipStatusString(this.flipInfo.status)
            this.flipInfo.betETH = web3.utils.fromWei(this.flipInfo.betETH.toString())
            this.flipInfo.betAIX = web3.utils.fromWei(this.flipInfo.betTokens.toString())
            this.flipInfo.winAIX = web3.utils.fromWei(this.flipInfo.winTokens.toString())
            if (this.flipInfo.flipStatus === 'Refunded') this.refunded = true
          })
      },
      refund() {
        const self = this
        this.FlipInstance.methods
          .refundFlip(this.cachedFlipId)
          .send({
            from: web3.eth.defaultAccount
          })
          .once('transactionHash', (txHash) => {
            this.showRefund = false
            this.refundStarted = true
            this.refundTxHash = txHash
            this.flipRefundInfo += 'Refund started...\n'
            this.flipRefundInfo += `Transaction: https://etherscan.io/tx/${txHash}\n`
          })
      }
    },
    created() {
      if (this.isWeb3Present) {
        this.FlipInstance = new web3.eth.Contract(config.CoinFlipABI, config.FlipAddress)
      }
      web3.eth.getAccounts().then(accounts => {
        web3.eth.defaultAccount = accounts[0]
      })
    }
  }

</script>

<style scoped>
  .container.flip {
    padding: 30px 100px;
  }

  .btn {
    margin: 10px auto;
    width: 160px;
    display: block;
  }

  .submit-button {
    display: block;
    margin-top: 5px;
    width: 160px;
  }

  .submit-button:focus {
    outline: 0;
  }

  .form-prize {
    text-align: center
  }

  .el-form {
    display: flex;
    flex-direction: column;
    justify-content: space-around;
  }

  h2 {
    text-align: center;
    margin: 20px auto;
  }

  p {
    font-size: 16px;
  }

  .bold {
    font-weight: 600;
  }

  .info-container {
    margin: 0;
    display: flex;
    flex-direction: column;
    align-items: center;
  }

  .info-container div {
    display: flex;
    flex-direction: row;
    margin: 5px auto;
    width: 100%;
  }

  .info-container div span:first-child {
    display: inline-block;
    min-width: 110px;
  }

  .info-container div span:first-child {
    text-align: right;
    margin-right: 10px;
  }

  .flip>p {
    margin-bottom: 20px;
  }

  .green-text {
    color: #2ecc71
  }

  .underline {
    text-decoration: underline;
  }

  .underline:hover {
    cursor: pointer;
  }

  .red-text {
    color: #F22613;
  }

  .green-text,
  .red-text,
  .text {
    font-size: 2rem;
    margin: 20px;
  }

  .info-container {
    margin-top: 20px;
  }

  @media only screen and (max-width: 765px) {
    .container.flip {
      padding: 20px 10px;
      margin: 10px;
    }

    .info-container span:last-child {
      flex-grow: 1;
      word-wrap: break-word;
      max-width: calc(100% - 120px);
    }
  }
</style>
