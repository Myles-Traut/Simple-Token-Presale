// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

///TODO Add claimHub function
///TODO Add withdrawWeth function

// Deployed addr : 0xD055B32fd3136F1dCA638Cd8f4B2eAF4A10abAb3

contract TokenPresale {

    /*------STORAGE------*/

    ///@dev stores the contracts WETH balance
    uint256 public balance;

    // How many token units a buyer gets per wei.
    // The rate is the conversion between wei and the smallest and indivisible token unit.
    // So, if you are using a rate of 1 with a ERC20Detailed token with 3 decimals called TOK
    // 1 wei will give you 1 unit, or 0.001 TOK.
    /// @notice The below rate works out to about 1.2HUB / 1USDC
    uint256 private _rate; // rate is 2e3 => 1 wei = 0.0000000000000002 HUB 

    address public owner;

    mapping(address => uint256) public userHubBalance;

    /*------EVENTS------*/

    event HubBought(address indexed buyer, uint256 indexed ethSpent, uint256 indexed hubBought);
    event EthWithdrawn(uint256 ethWithdrawn, uint256 remainingBalance);
    
    /*------CONSTRUCTOR------*/

    constructor() {
        _rate = 2e3;
        owner = msg.sender;
    }

    /*------STATE CHANGING FUNCTIONS------*/

    function buyHub(
        address _receiver
        ) public payable returns(uint256) {

        uint256 hubBought = _getHub(msg.value);
        balance += msg.value;
        userHubBalance[_receiver] += hubBought;

        emit HubBought(msg.sender, msg.value, hubBought);

        return (hubBought);
    }

    function withdrawETH(uint256 _amount) public {
        require(msg.sender == owner, "Only Owner");
        require(_amount <= balance, "Insufficient balance");
        (bool success, ) = msg.sender.call{value: _amount}("");
        require(success, "Withdrawal Failed");
        balance -= _amount;

        emit EthWithdrawn(_amount, balance);
    }

     /*------INTERNAL FUNCTIONS------*/

    function _getHub(uint256 _weiAmount) internal view returns(uint256) {
        return _weiAmount * _rate;
    }

    /*------VIEW FUNCTIONS------*/

    ///@notice gets the amount of HUB a user will receive for a given amount of wei.
    ///@param _weiAmount the amount of wei to get a quote for.
    ///@return hubQuote the amount of HUB received for _weiAmount
    function getHubQuote(uint256 _weiAmount) public view returns(uint256 hubQuote){
        hubQuote = _getHub(_weiAmount);
    }

    function rate() public view returns(uint256 rate_){
        rate_ = _rate;
    }
}
