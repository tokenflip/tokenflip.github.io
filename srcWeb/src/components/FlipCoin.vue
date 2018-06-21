<template>
  <div class="container">
    <span>NOTE: this game is for learning purposes, not gambling!</span>
    <div class="flip form">
      <div class="top-row">
        <HowToPlay />

        <div v-if="isLoggedIn" class="user-info-box">
          <span>Your wallet ETH balance:
            <b> {{ parseFloat(fromWei(accountBalanceETH)).toFixed(4) }} </b>
          </span>
          <span>Your AIX balance:
            <b>{{ fromWei(accountBalanceAIX) }}</b>
          </span>
        </div>
      </div>

      <CoinSpinner ref="spinner" />

      <div class="form-box">
        <label for="coin-side" class="form-label">Coin side:</label>

        <el-select :disabled="!isInputAllowed" style="width:205px;" v-model="selectedSide" @change="estimatePrize(); selectedSideChanged()">
          <el-option v-for="item in side" :key="item.value" :label="item.label" :value="item.value">
          </el-option>
        </el-select>
      </div>
      <div class="form-box">
        <label for="bet" class="form-label">Bet:</label>

        <el-input :disabled="!isInputAllowed" style="width:100px;" maxlength="4" v-model="betAmount" @input="estimatePrize" placeholder="Amount"></el-input>
        <el-select :disabled="!isInputAllowed" style="width:100px;" v-model="betCurrency" @change="estimatePrize">
          <el-option v-for="item in optionsCurrency" :key="item.value" :label="item.label" :value="item.value">
          </el-option>
        </el-select>

      </div>

      <div class="form-box" id="prize-row">
        <span class="form-prize">{{ estimatedPrize }}</span>
        <span v-if="inputIsCorrect" class="fee">(Oracle fee - {{ web3.utils.fromWei(oracleFee).toString() }} {{ betCurrency === 'eth' ? 'ETH' : 'AIX' }})</span>
      </div>

      <el-button :disabled="flipping" v-if="isWeb3Present && isLoggedIn && isOnCorrectNetwork" v-on:click='flip' class="form-btn btn">Flip</el-button>
      <MetamaskNotInstalled v-else-if="!isWeb3Present" />
      <el-alert v-else-if="!isOnCorrectNetwork" :closable="false" v-bind:title="'Flip is not working on \'' + 
        userNetId + '\' network, please switch to \'' + flipNetId + '\' network.'" type="error" center show-icon></el-alert>
      <el-alert v-else :closable="false" title="Please log in with your Ethereum Client to continue" type="error" center show-icon></el-alert>

      <pre v-if="flipStatus" id="flip-status">{{ flipStatus }}</pre>
    </div>

    <HistoryTable :table-data="history" />

    <TopWinnersTable :table-data="winners" />
  </div>
</template>

<script>
  import TopWinnersTable from '@/components/TopWinnersTable.vue'
  import HistoryTable from '@/components/HistoryTable.vue'
  import HowToPlay from '@/components/HowToPlay.vue'
  import CoinSpinner from '@/components/CoinSpinner.vue'
  import MetamaskNotInstalled from '@/components/MetamaskNotInstalled.vue'
  import Web3 from 'web3'
  import utils from '@/mixins/Utils.vue'
  import ContractMethods from '@/mixins/ContractMethodsMixin.vue'
  import GetFlipStatusMixin from '@/mixins/GetFlipStatusMixin.vue'
  import config from '@/config.json'
  var FlipInstance = null
  var InfuraFlipInstance = null
  var TokenInstance = null
  var ExchangeInstance = null;
  var web3 = window.web3 !== undefined ? new Web3(window.web3.currentProvider) : null
  var infuraWeb3 = new Web3(new Web3.providers.WebsocketProvider(config.InfuraWeb3))

  export default {
    name: "FlipCoin",
    components: {
      TopWinnersTable,
      HistoryTable,
      HowToPlay,
      MetamaskNotInstalled,
      CoinSpinner
    },
    mixins: [utils, ContractMethods, GetFlipStatusMixin],
    data() {
      return {
        defaultAccount: null,
        //flipNetId: 'ropsten',
        flipNetId: 'main',
        userNetId: null,
        loggedIn: false,
        BN: this.isWeb3Present ? web3.utils.BN : null,
        inputIsCorrect: false,
        accountBalanceETH: 0,
        accountBalanceAIX: 0,
        oracleFee: '0',
        selectedSide: 'obverse',
        betCurrency: 'aix',
        minBetETH: 0,
        maxBetETH: 0,
        minBetAIX: 0,
        maxBetAIX: 0,
        betAmount: '',
        betAmountInAIX: this.isWeb3Present ? new web3.utils.BN(0) : null,
        multiplier: this.isWeb3Present ? new web3.utils.BN(2) : null,
        txHash: '',
        flipID: '',
        flipStatus: '',
        estimatedPrize: '',
        flipping: false,
        waitingForStartEvent: false,
        waitingForEndEvent: false,
        history: {
          caption: 'Your flips history',
          gridColumns: ['FlipID', 'Bet (Token)', 'Bet (ETH)', 'Currency', 'Status'],
          gridData: [],
          numberOfRecords: 10,
          isLoading: false
        },
        winners: {
          caption: 'Top 5 Winners',
          gridColumns: ['Address', 'Token'],
          gridData: [],
          isLoading: false
        },
        optionsCurrency: [{
          value: 'aix',
          label: 'AIX'
        }, {
          value: 'eth',
          label: 'ETH'
        }],
        side: [{
          value: 'obverse',
          label: 'Obverse'
        }, {
          value: 'reverse',
          label: 'Reverse'
        }]
      }
    },
    computed: {
      FlipInstance() {
        return FlipInstance
      },
      TokenInstance() {
        return TokenInstance
      },
      web3() {
        return web3
      },
      isLoggedIn() {
        return this.defaultAccount !== null
      },
      isOnCorrectNetwork() {
        return this.userNetId === this.flipNetId
      },
      isWeb3Present() {
        return web3 !== null
      },
      isInputAllowed() {
        return !this.flipping && this.isLoggedIn && this.isOnCorrectNetwork
      }
    },
    methods: {
      flip() {
        this.tryToFlip()
      },
      tryToFlip() {
        if (!this.isInputValid(this.betAmount) || this.betAmount <= 0 || this.flipping)
          return;

        this.flipping = true;
        console.log("Flip started");
        window.ga('send', 'event', 'flipStarted');

        this.contractHasEnoughEther().then((contractHasEnoughEth) => {
          if (!contractHasEnoughEth) {
            this.showErrorBox("Contract does't have enough ETH in balance to pay for oracle.", "ERROR")
            return;
          }

          this.contractHasEnoughAix().then(contractHasEnoughAix => {
            if (contractHasEnoughAix) {
              if (this.betCurrency === 'eth') {
                this.playerHasEnoughEther()
                  .then(hasEnough => {
                    if (hasEnough) {
                      this.flipCoinWithEther();
                    } else {
                      this.endFlip();
                      this.showErrorBox("You don't have enough Ether", "ERROR")
                    }
                  })
              } else {
                this.playerHasEnoughAix()
                  .then(hasEnough => {
                    if (hasEnough) {
                      this.flipCoinWithAIX();
                    } else {
                      this.endFlip();

                      this.showErrorBox("You don't have enough Tokens", "ERROR")
                    }
                  })
              }
            } else {
              this.endFlip();
              this.availableContractTokensBalance().then(balance => {
                this.showErrorBox(
                  `Contract doesn't have enough Tokens. Available contract balance is ${this.fromWei(balance)} tokens. You can try with a smaller bet or try to flip later`,
                  "ERROR"
                )
              })
            }
          })
        })

      },
      estimatePrize() {
        if (!this.isInputValid(this.betAmount))
          return;

        this.multiplier = this.selectedSide === 'obverse' ? new web3.utils.BN(2) :
          this.selectedSide === 'reverse' ? new web3.utils.BN(2) : new web3.utils.BN(3)

        if (this.betCurrency === 'eth') {
          ExchangeInstance.methods.tokenToEthRate()
            .call({
              from: this.defaultAccount
            })
            .then((result) => {
              result = new web3.utils.BN(result)
              let betAmountBN = web3.utils.toBN(web3.utils.toWei(this.betAmount.toString()))
              let oneEtherBN = web3.utils.toBN(web3.utils.toWei('1'))
              this.getOracleFeeETH().then((fee) => {
                let feeBN = web3.utils.toBN(fee)
                betAmountBN = betAmountBN.sub(feeBN)
                this.betAmountInAIX = betAmountBN.div(result).mul(oneEtherBN)
                let estimatedPrize = web3.utils.toBN(this.betAmountInAIX)
                  .mul(this.multiplier).div(oneEtherBN)
                this.estimatedPrize = "Win prize: ~" + estimatedPrize + " AIX"
                this.inputIsCorrect = this.isInputValid(this.betAmount)
              })
            })
        } else {
          this.getOracleFeeAIX().then((fee) => {
            let feeBN = web3.utils.fromWei(fee)
            this.betAmountInAIX = new web3.utils.BN(web3.utils.toWei(this.betAmount))
            this.estimatedPrize = "Win prize: " +
              ((this.betAmount - feeBN) * this.multiplier) + " AIX"
            this.inputIsCorrect = this.isInputValid(this.betAmount)
          })
        }
      },
      changeHistoryRecord(flipID, status) {
        return new Promise((resolve, reject) => {
          for (let i = 0; i < this.history.gridData.length; i++) {
            if (this.history.gridData[i].FlipID === flipID) {
              this.history.gridData[i].Status = status;
              break;
            }
          }
          resolve();
        })
      },
      addHistoryRecord(flipID, flipInfo) {
        return new Promise((resolve, reject) => {
          let exists = false;
          for (let i = 0; i < this.history.gridData.length; i++) {
            if (this.history.gridData[i].FlipID === flipID) {
              exists = true;
              break;
            }
          }

          if (!exists) {
            // console.log("Record added ", flipID);
            // console.log(flipInfo);
            if (this.history.gridData.length >= this.history.numberOfRecords) {
              this.history.gridData.pop();
            }

            let betETH = web3.utils.fromWei(flipInfo.betETH.toString())
            this.history.gridData.unshift({
              FlipID: flipID,
              'Bet (Token)': web3.utils.fromWei(flipInfo.betTokens.toString()),
              'Bet (ETH)': betETH > 0 ? betETH : '-',
              Currency: flipInfo.currency === '1' ? 'ETH' : 'AIX',
              Status: this.getFlipStatusString(flipInfo.status)
            })
          }
          resolve();
        })
      },
      getSelectedSideIndex() {
        return this.selectedSide === 'obverse' ? 0 :
          this.selectedSide === 'reverse' ? 1 : 2;
      },
      catchFlipStartedEvents() {
        InfuraFlipInstance.events.FlipStarted({
          filter: {
            flipOwner: this.defaultAccount
          }
        })
          .on('data', (event) => {
            setTimeout(() => {
              let flipID = event.returnValues.flipID;
              FlipInstance.methods.flips(flipID).call({
                flipOwner: this.defaultAccount
              })
                .then((flipInfo) => {
                  this.addHistoryRecord(flipID, flipInfo)
                  if (event.transactionHash === this.txHash && this.waitingForStartEvent) {
                    this.waitingForStartEvent = false
                    this.waitingForEndEvent = true
                    this.$refs['spinner'].startSpinning()
                    this.flipID = flipID;
                    this.changeFlipStatus("Transaction mined")
                    this.changeFlipStatus("FlipID = " + flipID)
                    this.changeFlipStatus("Waiting for oracle...")
                  }
                })
            }, 3000)
          })
          .on('changed', (event) => { })
          .on('error', (error) => {
            if (this.$refs['spinner']) this.$refs['spinner'].endSpinning('obverse')
            this.changeFlipStatus("An error occurred");
            console.error(error)
            this.endFlip();
          })
      },
      catchFlipEndEvent() {
        InfuraFlipInstance.events.FlipEnded({
          filter: {
            flipOwner: this.defaultAccount
          }
        })
          .on('data', (event) => {
            setTimeout(() => {
              let flipID = event.returnValues.flipID
              FlipInstance.methods.flips(flipID).call({
                from: this.defaultAccount
              })
                .then((flipInfo) => {
                  let status = this.getFlipStatusString(flipInfo.status)
                  let winAIX = web3.utils.fromWei(flipInfo.winTokens.toString())
                  let resultSide = this.getFlipResultString(flipInfo.result)

                  if (flipID === this.flipID && this.flipping && this.waitingForEndEvent) {
                    this.waitingForEndEvent = false
                    if (status !== 'Refunded') {
                      if (this.$refs['spinner']) this.$refs['spinner'].endSpinning(resultSide)
                    } else {
                      if (this.$refs['spinner']) this.$refs['spinner'].endSpinning('obverse')
                    }

                    setTimeout(() => {
                      this.changeHistoryRecord(flipID, status);
                      this.changeFlipStatus("Flip ended")
                      if (status === 'Won') {
                        this.changeFlipStatus("You won " + winAIX + " AIX, congrats!");
                      } else if (status === 'Lost') {
                        this.changeFlipStatus("You lost, play again");
                      } else if (status === 'Refunded') {
                        this.changeFlipStatus("Flip was refunded");
                      } else { console.log(`Unexpected status: ${status}`);
                      }
                      this.endFlip();
                    }, 2000)
                  } else {
                    this.changeHistoryRecord(flipID, status);
                  }
                })
            }, 3000)
          })
          .on('changed', (event) => { })
          .on('error', (error) => {
            if (this.$refs['spinner']) this.$refs['spinner'].endSpinning('obverse')
            this.changeFlipStatus("An error occurred");
            console.error(error)
            this.endFlip();
          })
      },
      showErrorBox(text, title) {
        this.$alert(text, title, {
          type: 'error',
          customClass: 'error-box',
          showClose: false,
          center: true,
          confirmButtonClass: 'btn',
          showConfirmButton: true
        })
      },
      selectedSideChanged() {
        if (this.$refs['spinner']) this.$refs['spinner'].sideChanged(this.selectedSide)
      },
      endFlip() {
        this.flipping = false
        this.waitingForStartEvent = false
        this.waitingForEndEvent = false
      },
      changeFlipStatus(text) {
        console.log(text);
        this.flipStatus += text + "\n";
      },
      getBalances() {
        if (this.isLoggedIn) {
          web3.eth.getBalance(this.defaultAccount).then((balance) => {
            this.accountBalanceETH = balance
          })

          TokenInstance.methods.balanceOf(this.defaultAccount).call({
            from: this.defaultAccount
          }).then((balance) => {
            this.accountBalanceAIX = balance
          })
        }
      },
      watchWeb3Accounts() {
        setInterval(() => {
          web3.eth.getCoinbase().then(defaultAddress => {
            if (this.defaultAccount !== defaultAddress) {
              this.defaultAccount = defaultAddress
              this.setMinMaxValues()

              if (defaultAddress === null) {
                this.history.isLoading = false
              } else {
                this.history.isLoading = true
              }

              this.reset();
              this.setFlipsHistory()
              // this.checkNetwork()
            }


            this.checkNetwork().then(() => {
              if (this.isOnCorrectNetwork) {
                this.getBalances()
              }
            })
          })
        }, 500)
      },
      checkNetwork() {
        return new Promise((resolve, reject) => {
          web3.eth.net.getNetworkType((error, netId) => {
            if (error != null) {
              console.log("ERORR: " + error)
              this.userNetId = null
            } else {
              if (this.userNetId !== netId) {
                this.userNetId = netId
                if (this.isOnCorrectNetwork) {
                  console.log(`Connected to correct '${this.userNetId}' network.`)
                } else {
                  console.log(`Flip will not work on '${this.userNetId}' network. Please switch to '${this.flipNetId}' network`)
                }
              }
            }
            resolve()
          })
        })
      },
      reset() {
        this.flipID = ''
        this.history.gridData = []
        this.selectedSide = 'obverse'
        this.betCurrency = 'aix'
        this.betAmount = ''
        this.flipStatus = ''
        this.flipping = false
        this.txHash = ''
        this.flipID = ''
        this.setMinMaxValues().then(() => {
          this.estimatedPrize = `Amount must be [${this.minBetAIX} - ${this.maxBetAIX}]`
        })
      }
    },
    created() {
      if (this.isWeb3Present) {
        FlipInstance = new web3.eth.Contract(config.CoinFlipABI, config.FlipAddress)
        InfuraFlipInstance = new infuraWeb3.eth.Contract(config.CoinFlipABI, config.FlipAddress)
        TokenInstance = new web3.eth.Contract(config.TokenABI, config.TokenAddress)
        ExchangeInstance = new web3.eth.Contract(config.ExchangeABI, config.ExchangeAddress)

        this.checkNetwork().then(() => {
          if (this.isOnCorrectNetwork) {
            this.setMinMaxValues()
            this.winners.isLoading = true
            this.watchWeb3Accounts()
            this.setTopWinners()
          }
        })
      } else {
        this.history.isLoading = false
        this.winners.isLoading = false
        console.log("Ethereum Client not found")
      }
    }

  }

</script>

<style>
  @media only screen and (max-width: 800px) {
    .error-box {
      width: 60%;
    }
  }

  @media only screen and (max-width: 450px) {
    .error-box {
      width: 90%;
    }
    .form.flip,
    .history,
    .winners {
      padding: 20px 10px;
      margin: 5px;
    }
    .form>.el-alert {
      margin-right: 0;
      margin-left: 0;
    }
  }

  @media only screen and (max-width: 323px) {
    .form-label {
      text-align: center;
      width: 100%;
      display: inline-block;
    }
    .el-select,
    .el-input {
      width: 100% !important;
      margin: 5px auto;
    }
  }

  .table-container {
    overflow-x: auto;
    max-width: 100%;
  }

  .tableCaption {
    font-size: 3rem;
    font-weight: bold;
    display: flex;
    justify-content: center;
    padding-bottom: 10px;
  }

  .form>.el-alert {
    font-weight: bold;
    border: 1px solid;
  }

  .top-row {
    display: flex;
    flex-direction: row;
    justify-content: space-between;
  }

  .user-info-box {
    display: flex;
    flex-direction: column;
    text-align: right;
    font-size: 1.5rem;
    overflow-x: auto;
    padding: 15px;
  }

  .user-info-box span {
    text-align: right !important;
  }

  #flip-status {
    width: 100%;
    overflow-y: hidden;
    overflow-x: auto;
    margin-top: 2%;
    background-color: rgb(241, 241, 241);
  }

  .error-box p {
    color: red;
    font-size: 1.5rem;
    font-weight: bold;
  }

  #prize-row {
    width: 100%;
    text-align: center;
  }

  .fee {
    color: red;
    font-size: 1.5rem;
    margin-top: 0px !important;
  }

  button.is-disabled {
    background-color: lightgrey !important;
    color: grey !important;
    opacity: 0.5;
  }
</style>