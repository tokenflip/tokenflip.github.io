pragma solidity ^ 0.4.21;

import "./interface/IERC20.sol";
import "./utils/Owned.sol";
import "./utils/SafeMath.sol";
import "./interface/IExchange.sol";
import "./utils/UsingOraclize.sol";

contract CoinFlip is Owned, usingOraclize {
    using SafeMath for uint;

    IERC20 public token;
    IExchange public exchange;

    enum FlipStatus {
        NotSet,
        Flipping,
        Won,
        Lost,
        Refunded
    }

    enum BetCurrency {
        NotSet,
        ETH,
        Token
    }

    bool public paused;
    uint8 public maxCoinSides = 2;

    uint public minAllowedBetInTokens = 10 ether; // 10 Token
    uint public maxAllowedBetInTokens = 1000 ether; // 1000 Token

    uint public minAllowedBetInEth = 0.01 ether;
    uint public maxAllowedBetInEth = 0.5 ether;

    uint public oracleCallbackGasLimit = 200000;
    uint public oracleCallbackGasPrice = 1e9;  // 1 gwei

    uint public tokensRequiredForAllWins; // Amount needed to pay if every bet is a win

    uint public ETHFee = 0.0002 ether;  
    uint public tokenFee = 2 ether; // 2 token

    bytes32[] public flipIds;
    mapping(bytes32 => Flip) public flips;

    struct Flip {
        address owner;
        BetCurrency currency;
        FlipStatus status;
        bool completed;
        uint8 numberOfCoinSides;
        uint8 playerChosenSide;
        uint result;
        uint betETH;
        uint etherTokenRate; // Rate at which ether was exchanged to tokens (if Ether was used to bet)
        uint betTokens;
        uint winTokens;
    }

    modifier notPaused() {
        require(!paused);
        _;
    }

    modifier senderIsToken() {
        require(msg.sender == address(token));
        _;
    }

    /// Constructor
    constructor() public {   
        paused = true;
        oraclize_setCustomGasPrice(oracleCallbackGasPrice);
    }

    function initialize(address _token, address _exchange) external onlyOwner {
        token = IERC20(_token) ;
        exchange = IExchange(_exchange);
        paused = false;
    }

    function () public payable {
        require(false);
    }

    function flipCoinWithEther(uint8 _numberOfCoinSides, uint8 _playerChosenSide) external payable notPaused {        
        require(msg.value >= minAllowedBetInEth && msg.value <= maxAllowedBetInEth);

        emit ETHStart(msg.sender, msg.value);
        uint ethValueAfterFees = msg.value.sub(ETHFee);
        uint rate = exchange.tokenToEthRate();
        uint expectedAmountOfTokens = SafeMath.div(ethValueAfterFees, rate).mul(1 ether);

        emit RateCalculated(rate);

        _checkGeneralRequirements(expectedAmountOfTokens, _numberOfCoinSides, _playerChosenSide);

        _initializeFlip(msg.sender, BetCurrency.ETH, expectedAmountOfTokens, ethValueAfterFees, _numberOfCoinSides, _playerChosenSide, rate);
    }

    /// @dev Called by token contract after Approval
    function receiveApproval(address _from, uint _amountOfTokens, address _token, bytes _data) external senderIsToken notPaused {
        uint8 numberOfCoinSides = uint8(_data[31]);
        uint8 playerChosenSide = uint8(_data[63]);

        require((_amountOfTokens >= minAllowedBetInTokens) && (_amountOfTokens <= maxAllowedBetInTokens), "Invalid tokens amount.");

        emit TokenStart(msg.sender, _from, _amountOfTokens);

        uint tokensAmountAfterFees = _amountOfTokens.sub(tokenFee);

        _checkGeneralRequirements(tokensAmountAfterFees, numberOfCoinSides, playerChosenSide);

        // Transfer tokens from sender to this contract
        require(token.transferFrom(_from, address(this), _amountOfTokens), "Tokens transfer failed.");

        emit TokenTransferExecuted(_from, address(this), _amountOfTokens);

        _initializeFlip(_from, BetCurrency.Token, tokensAmountAfterFees, 0, numberOfCoinSides, playerChosenSide, 0);
    }

    function _checkGeneralRequirements(uint _amountOfTokens, uint8 _numberOfCoinSides, uint8 _playerChosenSide) private {
        // Check if player selected coin side is valid
        require(_numberOfCoinSides >= 2 && _numberOfCoinSides <= maxCoinSides, "Invalid number of coin sides.");
        require(_playerChosenSide <= _numberOfCoinSides, "Invalid player chosen side");

        tokensRequiredForAllWins = tokensRequiredForAllWins.add(_amountOfTokens.mul(_numberOfCoinSides));

        // Check if contract has enough tokens to pay in case of win.
        // Each successful flip start adds bet value in tokens to 'tokensRequiredForAllWins'
        require(tokensRequiredForAllWins <= token.balanceOf(address(this)), "Not enough tokens in contract balance.");
    }

    // _numberOfCoinSides (2 - [O] obverse [1] reverse)
    function _initializeFlip(address _from, BetCurrency _currency, uint _amountOfTokens, uint _ethAmount, uint8 _numberOfCoinSides, uint8 _playerChosenSide, uint _rate) private {
        string memory query;

        if(_numberOfCoinSides == 2) {
            query = "random integer between 0 and 1"; 
        }
        else if(_numberOfCoinSides == 3) {
            query = "random integer between 0 and 2"; 
        }
        else {
            revert("Query not found for provided number of coin sides."); 
        }
        
        bytes32 flipId = oraclize_query("WolframAlpha", query, oracleCallbackGasLimit);  

        flipIds.push(flipId);
        flips[flipId].owner = _from;
        flips[flipId].betTokens = _amountOfTokens;
        flips[flipId].betETH = _ethAmount;
        flips[flipId].numberOfCoinSides = _numberOfCoinSides;
        flips[flipId].playerChosenSide = _playerChosenSide;
        flips[flipId].currency = _currency;
        flips[flipId].etherTokenRate = _rate;
        flips[flipId].status = FlipStatus.Flipping;

        emit FlipStarted(flipId, _from, _amountOfTokens);
    }


    /// @dev Called by oraclize to return generated random number.
    ///  Transaction will fail if gas limit provided earlier was too low
    /// @param myid FlipID which this callback was targeted to
    /// @param result Generated random number
    function __callback(bytes32 myid, string result) public {
        require(!flips[myid].completed, "Callback to already completed flip.");
        require(msg.sender == oraclize_cbAddress(), "Callback caller is not oraclize address.");
        flips[myid].completed = true;
        
        // Assigning received random number.
        // Picking only first byte because result is expected to be single ASCII char ('0' or '1' or '2')
        // Subtracting 48 because in ASCII table decimal 48 equals '0', 49 equals '1' etc.
        emit OracleResult(bytes(result)[0]);
        flips[myid].result = uint8(bytes(result)[0]) - 48;
        assert(flips[myid].result >= 0 && flips[myid].result <= flips[myid].numberOfCoinSides);
        
        if(flips[myid].result == flips[myid].playerChosenSide) {
            flips[myid].status = FlipStatus.Won;
            flips[myid].winTokens = SafeMath.mul(flips[myid].betTokens, flips[myid].numberOfCoinSides);
            require(token.transfer(flips[myid].owner, flips[myid].winTokens), "Tokens transfer failed.");
        }
        else {
            flips[myid].status = FlipStatus.Lost;
        }
        
        tokensRequiredForAllWins = tokensRequiredForAllWins.sub(flips[myid].betTokens.mul(flips[myid].numberOfCoinSides));
        emit FlipEnded(myid, flips[myid].owner, flips[myid].winTokens);
    }

    /// @dev Refund bet manually if oraclize callback was not received
    /// @param _flipId Targeted flip
    function refundFlip(bytes32 _flipId) external {
        require(msg.sender == flips[_flipId].owner || msg.sender == owner, "Refund caller is not owner of this flip.");
        require(!flips[_flipId].completed, "Trying to refund completed flip.");
        flips[_flipId].completed = true;
        
        if(flips[_flipId].currency == BetCurrency.ETH) {
            // Return ether if ether was used to bet for flip
            flips[_flipId].owner.transfer(flips[_flipId].betETH);
        }
        else {
            // Return tokens if tokens were used to bet for flip
            assert(token.transfer(flips[_flipId].owner, flips[_flipId].betTokens));
        }
        
        tokensRequiredForAllWins = tokensRequiredForAllWins.sub(flips[_flipId].betTokens.mul(flips[_flipId].numberOfCoinSides));
        flips[_flipId].status = FlipStatus.Refunded;
        emit FlipEnded(_flipId, flips[_flipId].owner, flips[_flipId].winTokens);
    }

    
    function setOracleCallbackGasPrice(uint _newPrice) external onlyOwner {
        require(_newPrice > 0, "Gas price must be more than zero.");
        oracleCallbackGasPrice = _newPrice;
        oraclize_setCustomGasPrice(oracleCallbackGasPrice);
    }

    function setOracleCallbackGasLimit(uint _newLimit) external onlyOwner {
        oracleCallbackGasLimit = _newLimit;
    }

    function setMinAllowedBetInTokens(uint _newMin) external onlyOwner {
        minAllowedBetInTokens = _newMin;
    }

    function SetMaxAllowedBetInTokens(uint _newMax) external onlyOwner {
        maxAllowedBetInTokens = _newMax;
    }

    function setMinAllowedBetInEth(uint _newMin) external onlyOwner {
        minAllowedBetInEth = _newMin;
    }

    function setMaxAllowedBetInEth(uint _newMax) external onlyOwner {
        maxAllowedBetInEth = _newMax;
    }

    function setMaxCoinSides(uint8 _newMax) external onlyOwner {
        maxCoinSides = _newMax;
    }

    function setETHFee(uint _value) external onlyOwner {
        ETHFee = _value;
    }

    function tokenFee(uint _value) external onlyOwner {
        tokenFee = _value;
    }
    
    //////////
    // Safety Methods
    //////////
    function depositETH() external payable onlyOwner {
    }

    function withdrawETH(uint _wei) external onlyOwner {
        owner.transfer(_wei);
    }

    function withdrawToken(uint _amount) public onlyOwner {
        token.transfer(owner, _amount);
    }

    function withdrawTokens(uint _amount, address _token) external onlyOwner {
        IERC20(_token).transfer(owner, _amount);
    }

    function pause(bool _paused) external onlyOwner {
        paused = _paused;
    }


    ///////////////////
    // STATS
    ///////////////////

    ///////////////////
    // FLIPS
    ///////////////////
    function getNumberOfFlips(address _account) private view returns(uint) {
        uint result = 0;

        if (_account == address(0)) {
            result = flipIds.length;
        } else {
            for (uint i = 0; i < flipIds.length; i++) {
                if (flips[flipIds[i]].owner == _account) {
                    result++;
                }
            }
        }
        
        return result;
    }

    function getTotalFlips() private view returns(uint) {
        return flipIds.length;
    }

    function getPlayerFlips(address _account, uint _number) external view returns(bytes32[]) {
        uint index;
        uint accountFlips = getNumberOfFlips(_account);
        uint number = _number;

        if (_number > accountFlips) {
            number = accountFlips;
        }

        bytes32[] memory playerFlips = new bytes32[](number);

        for (uint i = flipIds.length - 1; i >= 0; i--) {
            if (flips[flipIds[i]].owner == _account) {
                playerFlips[index] = flipIds[i];
                index++;
            }

            if (index == number || i == 0) {
                break;
            }
        }

        return playerFlips;
    }

    function flipsCompleted() public view returns(uint) {
        uint result = 0;
        for (uint i = 0; i < flipIds.length; i++) {
            if (flips[flipIds[i]].status == FlipStatus.Won ||
                flips[flipIds[i]].status == FlipStatus.Lost){
                    result++;
                }
        }
        return result;
    }
 

    function flipsWon() public view returns(uint) {
        uint result = 0;
        for (uint i = 0; i < flipIds.length; i++) {
            if (flips[flipIds[i]].status == FlipStatus.Won) 
            {
                result++;
            }
        }
        return result;
    }

    function flipsLost() public view returns(uint) {
        uint result = 0;
        for (uint i = 0; i < flipIds.length; i++) {
            if (flips[flipIds[i]].status == FlipStatus.Lost) 
            {
                result++;
            }
        }
        return result;
    }


    function getTopWinners(uint _number) external view returns(bytes32[]) {
        uint number = _number > 5 ? _number : 5;
        uint[] memory topWins = new uint[](number);
        bytes32[] memory flipsList = new bytes32[](number);

        for (uint i = 0; i < flipIds.length; i++) {
            uint winValue = flips[flipIds[i]].winTokens;

            for (uint j = 0; j < number; j++) {
                if (winValue > topWins[j]) {
                    for (uint k = number - 1; k > j; k--) {
                        topWins[k] = topWins[k - 1];
                        flipsList[k] = flipsList[k - 1];
                    }
                    topWins[j] = winValue;
                    flipsList[j] = flipIds[i];
                    break;
                }
            }
        }

        return flipsList;
    }

    ///////////////////
    // BETS IN ETHER
    ///////////////////
    function avgEtherBetValue() public view returns(uint) {
        return totalEtherBetValue().div(flipsCompleted());
    }

    function totalEtherBetValue() public view returns(uint) {
        uint total = 0;

        for (uint i = 0; i < flipIds.length; i++) {
            if (flips[flipIds[i]].currency == BetCurrency.ETH) {
                total = total.add(flips[flipIds[i]].betETH);
            }
        }

        return total;
    }

    ///////////////////
    // BETS IN TOKENS
    ///////////////////
    function maxTokenBetValue() external view returns(uint) {
        uint result = 0;

        for (uint i = 0; i < flipIds.length; i++) {
            if (flips[flipIds[i]].currency == BetCurrency.Token && 
                flips[flipIds[i]].betTokens > result) {
                    result = flips[flipIds[i]].betTokens;
                } 
        }

        return result;
    }

    function maxTokenWinValue() external view returns(uint) {
        uint result = 0;

        for (uint i = 0; i < flipIds.length; i++) {
            if (flips[flipIds[i]].currency == BetCurrency.Token &&
                flips[flipIds[i]].status == FlipStatus.Won &&
                flips[flipIds[i]].winTokens > result) {
                    result = flips[flipIds[i]].winTokens;
                }
        }

        return result;
    }

    function maxTokenlossValue() external view returns(uint) {
        uint result = 0;

        for (uint i = 0; i < flipIds.length; i++) {
            if (flips[flipIds[i]].currency == BetCurrency.Token &&
                flips[flipIds[i]].status == FlipStatus.Lost &&
                flips[flipIds[i]].betTokens > result) {
                result = flips[flipIds[i]].betTokens;
            }
        }

        return result;
    }

    function avgTokenBetValue() public view returns(uint) {
        return totalTokenBetValue().div(flipsCompleted());
    }

    function avgTokenWinValue() public view returns(uint) {
        return totalTokenWinValue().div(flipsWon());
    }

    function avgTokenlossValue() public view returns(uint) {
        return totalTokenLossValue().div(flipsLost());
    }

    function totalTokenBetValue() public view returns(uint) {
        uint result = 0;
        for (uint i = 0; i < flipIds.length; i++) {
            if (flips[flipIds[i]].currency == BetCurrency.Token) {
                result = result.add(flips[flipIds[i]].betTokens);
            }
        }
        return result;
    }

    function totalTokenWinValue() public view returns(uint) {
        uint result = 0;
        for (uint i = 0; i < flipIds.length; i++) {
            if (flips[flipIds[i]].currency == BetCurrency.Token && 
                flips[flipIds[i]].status == FlipStatus.Won) {
                result = result.add(flips[flipIds[i]].winTokens);
            }            
        }
        return result;
    }

    function totalTokenLossValue() public view returns(uint) {
        uint result = 0;
        for (uint i = 0; i < flipIds.length; i++) {
            if (flips[flipIds[i]].currency == BetCurrency.Token && 
                flips[flipIds[i]].status == FlipStatus.Lost){
                result = result.add(flips[flipIds[i]].betTokens);
            }
        }
        return result;
    }

    ///////////////////
    // BETS IN Tokens and ETH
    ///////////////////

    function totalWinValue() public view returns(uint) {
        uint result = 0;
        for (uint i = 0; i < flipIds.length; i++) {
            if (flips[flipIds[i]].status == FlipStatus.Won) {
                result = result.add(flips[flipIds[i]].winTokens);
            }            
        }
        return result;
    }

    function totalLossValue() public view returns(uint) {
        uint result = 0;
        for (uint i = 0; i < flipIds.length; i++) {
            if (flips[flipIds[i]].status == FlipStatus.Lost){
                result = result.add(flips[flipIds[i]].betTokens);
            }
        }
        return result;
    }

    function totalNotCompleted() public view returns(uint) {
        uint result = 0;
        for (uint i = 0; i < flipIds.length; i++) {
            if (flips[flipIds[i]].completed == false){
                result = result.add(1);
            }
        }
        return result;
    }

    function totalRefunded() public view returns(uint) {
        uint result = 0;
        for (uint i = 0; i < flipIds.length; i++) {
            if (flips[flipIds[i]].status == FlipStatus.Refunded){
                result = result.add(1);
            }
        }
        return result;
    }


    event TokenStart(address indexed sender, address indexed owner, uint value);
    event TokenTransferExecuted(address indexed from, address indexed receiver, uint value);
    event ETHStart(address indexed sender, uint value);
    event RateCalculated(uint value);
    event OracleResult(bytes1 value);
    event FlipStarted(bytes32 indexed flipID, address indexed flipOwner, uint amountOfTokens);
    event FlipEnded(bytes32 indexed flipID, address indexed flipOwner, uint winTokens);
}