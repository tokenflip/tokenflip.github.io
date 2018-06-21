<script>
  export default {
    methods: {
      availableContractTokensBalance() {
        return new Promise((resolve, reject) => {

          this.TokenInstance.methods.balanceOf(this.FlipInstance.options.address).call({
            from: this.defaultAccount
          })
            .then(contractBalance => {
              this.FlipInstance.methods.tokensRequiredForAllWins().call({
                from: this.defaultAccount
              }).then((reserved) => {
                contractBalance = this.web3.utils.toBN(contractBalance);
                reserved = this.web3.utils.toBN(reserved);
                let available = contractBalance.sub(reserved)
                resolve(available);
              })
            });

        });
      },
      contractHasEnoughAix() {
        return new Promise((resolve, reject) => {
          this.FlipInstance.methods.tokensRequiredForAllWins()
            .call({
              from: this.defaultAccount
            })
            .then((currentReserve) => {
              this.TokenInstance.methods.balanceOf(this.FlipInstance.options.address).call({
                from: this.defaultAccount
              })
                .then(contractBalance => {
                  currentReserve = new this.web3.utils.BN(currentReserve);
                  contractBalance = new this.web3.utils.BN(contractBalance);

                  let betAmount = new this.web3.utils.BN(this.betAmountInAIX);
                  let multiplier = this.multiplier;
                  let winAmount = new this.web3.utils.BN(betAmount).mul(new this.web3.utils.BN(multiplier))
                  let neededReserve = new this.web3.utils.BN(currentReserve).add(winAmount);
                  let hasEnough = contractBalance.cmp(neededReserve) === 1;
                  resolve(hasEnough);
                })
            })
        })
      },
      contractHasEnoughEther() {
        return new Promise((resolve, reject) => {
          this.web3.eth.getBalance(this.FlipInstance.options.address)
            .then(contractBalance => {
              contractBalance = new this.web3.utils.BN(contractBalance);
              let minRequiredAmount = new this.web3.utils.BN(this.web3.utils.toWei('0.1'))
              let hasEnough = contractBalance.gte(minRequiredAmount)
              resolve(hasEnough);
            });
        });
      },
      playerHasEnoughEther() {
        return new Promise((resolve, reject) => {
          this.web3.eth.getBalance(this.defaultAccount)
            .then(playerBalance => {
              playerBalance = new this.web3.utils.BN(playerBalance);
              let betAmount = new this.web3.utils.BN(this.web3.utils.toWei(this.betAmount.toString()));
              let hasEnough = playerBalance.cmp(betAmount) === 1;
              resolve(hasEnough);
            });
        });
      },
      playerHasEnoughAix() {
        return new Promise((resolve, reject) => {
          this.TokenInstance.methods.balanceOf(this.defaultAccount).call({
            from: this.defaultAccount
          })
            .then(playerBalance => {
              playerBalance = new this.web3.utils.BN(playerBalance);
              let hasEnough = playerBalance.cmp(this.betAmountInAIX) === 1;
              resolve(hasEnough);
            });
        });
      },
      flipCoinWithEther() {
        window.ga('send', 'event', 'metamaskPopup', 'start', 'labelETH');
        this.FlipInstance.methods.flipCoinWithEther(this.multiplier, this.getSelectedSideIndex())
          .send({
            from: this.defaultAccount,
            value: this.web3.utils.toWei(this.betAmount.toString())
          })
          .once('transactionHash', (txHash) => {
            this.onTxHash(txHash)
             window.ga('send', 'event', 'metamask', 'txLead', 'labelETH');
            
          })
          .once('receipt', (receipt) => { })
          .on('error', (error) => {
            console.log(error);
            this.endFlip();
          })
      },
      flipCoinWithAIX() {
        window.ga('send', 'event', 'metamaskPopup', 'start', 'labelAIX');
        let bytes = this.web3.eth.abi.encodeParameters(['uint8', 'uint8'], [2, this.getSelectedSideIndex()])
        this.TokenInstance.methods.approveAndCall(this.FlipInstance.options.address,
          this.web3.utils.toWei(this.betAmount), bytes)
          .send({
            from: this.defaultAccount
          })
          .once('transactionHash', (txHash) => {
            this.onTxHash(txHash)
             window.ga('send', 'event', 'metamask', 'txLead', 'labelAIX');
          })
          .once('receipt', (receipt) => { })
          .on('error', (error) => {
            console.log(error)
            this.endFlip();
          })
      },
      onTxHash(txHash) {
        this.flipStatus = "";
        this.txHash = txHash
        this.changeFlipStatus(
          `Transaction created: https://etherscan.io/tx/${txHash}`
        )

        this.changeFlipStatus("Transaction pending...")
        this.waitingForStartEvent = true
        this.$refs['spinner'].waitForSpinStart()
      },
      setFlipsHistory() {
        return new Promise((resolve, reject) => {
          this.FlipInstance.methods.getPlayerFlips(this.defaultAccount,
            this.history.numberOfRecords).call({
              from: this.defaultAccount
            })
            .then(result => {
              if (result.length == 0) {
                this.history.isLoading = false
                resolve();
              } else {
                result.reverse();
                (async () => {
                  let history = [];
                  for (let i = 0; i < result.length; i++) {
                    await new Promise(next => {
                      let flipID = result[i];
                      this.FlipInstance.methods.flips(flipID).call({
                        from: this.defaultAccount
                      })
                        .then(flipInfo => {
                          let betETH = this.web3.utils.fromWei(flipInfo.betETH.toString())
                          history.push({
                            FlipID: flipID,
                            'Bet (Token)': this.web3.utils.fromWei(flipInfo.betTokens.toString()),
                            'Bet (ETH)': betETH > 0 ? betETH : '-',
                            Currency: flipInfo.currency === '1' ? 'ETH' : 'AIX',
                            Status: this.getFlipStatusString(flipInfo.status)
                          })
                          next()
                        });
                    });
                  }
                  this.history.gridData = history.reverse()
                  this.history.isLoading = false
                  resolve();
                })();
              }
            })
        })
          .then(() => {
            this.catchFlipStartedEvents()
            this.catchFlipEndEvent()
          });
      },
      setTopWinners() {
        return new Promise((resolve, reject) => {
          this.FlipInstance.methods.getTopWinners(5).call({
            from: this.defaultAccount
          })
            .then(result => {
              (async () => {
                result = result.filter((i) => (this.web3.utils.toBN(i).toString() !== '0'))
                let winners = [];
                for (let i = 0; i < result.length; i++) {
                  await new Promise(next => {
                    this.FlipInstance.methods.flips(result[i]).call({
                      from: this.defaultAccount
                    })
                      .then(flipInfo => {
                        let result = this.web3.utils.fromWei(flipInfo.winTokens.toString())
                        winners.push({
                          Address: flipInfo.owner,
                          Token: result
                        });
                        next()
                      })
                  });
                }
                this.winners.gridData = winners
                this.winners.isLoading = false
                resolve()
              })()
            })
        })
      }
    }
  }

</script>