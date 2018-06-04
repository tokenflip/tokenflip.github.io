pragma solidity ^0.4.21;

contract IExchange {
    function ethToTokens(uint _ethAmount) public view returns(uint);
    function tokenToEth(uint _amountOfTokens) public view returns(uint);
    function tokenToEthRate() public view returns(uint);
    function ethToTokenRate() public view returns(uint);
}