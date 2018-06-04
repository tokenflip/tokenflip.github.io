var CoinFlip = artifacts.require("CoinFlip");
//var TestToken = artifacts.require("TestToken");

module.exports = function(deployer) {
  deployer.deploy(CoinFlip);
//  deployer.deploy(TestToken);
}
