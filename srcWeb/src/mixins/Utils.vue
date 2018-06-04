<script>
    export default {
        methods: {
            isInputValid(betAmount) {
                this.error = ''
                let regEx = betAmount.match(/^([0-9]+(\.[0-9]+)?)$/)
                let isCorrect = true
                let isNumber = regEx != null;

                let amount = parseFloat(betAmount);
                if (this.betCurrency === 'eth') {
                    if (!isNumber || amount < this.minBetETH || amount > this.maxBetETH) {
                        this.estimatedPrize = `Amount must be [${this.minBetETH} - ${this.maxBetETH}]`
                        isCorrect = false
                    }
                } else if (!isNumber || amount < this.minBetAIX || amount > this.maxBetAIX) {
                    this.estimatedPrize = `Amount must be [${this.minBetAIX} - ${this.maxBetAIX}]`
                    isCorrect = false
                }

                if (!isCorrect) {
                    this.inputIsCorrect = isCorrect
                    this.oracleFee = ''
                }

                return isCorrect;
            },
            getFlipStatusString(statusIndex) {
                return statusIndex === '0' ? 'NotSet' :
                    statusIndex === '1' ? 'Flipping' :
                        statusIndex === '2' ? 'Won' :
                            statusIndex === '3' ? 'Lost' : 'Refunded'
            },
            getFlipResultString(sideIndex) {
                return sideIndex === '0' ? 'obverse' :
                    sideIndex === '1' ? 'reverse' : 'edge'
            },
            getOracleFeeETH() {
                return new Promise((resolve, reject) => {
                    this.FlipInstance.methods.ETHFee().call({
                        from: this.defaultAccount
                    })
                        .then((fee) => {
                            this.oracleFee = fee
                            resolve(fee)
                        })
                })
            },
            getOracleFeeAIX() {
                return new Promise((resolve, reject) => {
                    this.FlipInstance.methods.tokenFee().call({
                        from: this.defaultAccount
                    })
                        .then((fee) => {
                            this.oracleFee = fee
                            resolve(fee)
                        })
                })
            },
            setMinMaxValues() {
                return new Promise((resolve, reject) => {
                    this.FlipInstance.methods.minAllowedBetInEth().call({
                        from: this.defaultAccount
                    }).then((result) => {
                        this.minBetETH = this.fromWei(result)
                        this.FlipInstance.methods.maxAllowedBetInEth().call({
                            from: this.defaultAccount
                        }).then((result) => {
                            this.maxBetETH = this.fromWei(result)
                            this.FlipInstance.methods.minAllowedBetInTokens().call({
                                from: this.defaultAccount
                            }).then((result) => {
                                this.minBetAIX = this.fromWei(result)
                                this.FlipInstance.methods.maxAllowedBetInTokens().call({
                                    from: this.defaultAccount
                                }).then((result) => {
                                    this.maxBetAIX = this.fromWei(result)
                                    resolve()
                                })
                            })
                        })
                    })
                })
            },
            fromWei(bigNumber) {
                return this.web3.utils.fromWei(bigNumber.toString())
            },
            toWei(number) {
                return this.web3.utils.toWei(number.toString())
            }
        }
    }
</script>