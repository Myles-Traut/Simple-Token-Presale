// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "lib/universal-router/contracts/interfaces/IUniversalRouter.sol";
import "lib/universal-router/contracts/libraries/Constants.sol";
import "lib/universal-router/contracts/libraries/Commands.sol";
import "lib/universal-router/permit2/src/Permit2.sol";
import "lib/universal-router/permit2/src/interfaces/ISignatureTransfer.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

///TODO Add claimHub function
///TODO Add withdrawWeth function

contract TokenPresale is Ownable {
    ///@notice This contract is able to:
    /*  Sell users HUB tokens based on a rate vs WEI.
        Users are able to purchase HUB in ERC20 tokens
        ERC20 tokens can be approved and removed by the contract owner.
        User HUB balances are kept in a mapping and become claimable after launch
        Deposited ERC20s are swapped for WETH upon deposit via the uniswap UR and stored in a balance var.
        Profits are only withdrawable by the contact owner */

    /*------STORAGE------*/

    ///@dev stores the contracts WETH balance
    uint256 public balance;

    // How many token units a buyer gets per wei.
    // The rate is the conversion between wei and the smallest and indivisible token unit.
    // So, if you are using a rate of 1 with a ERC20Detailed token with 3 decimals called TOK
    // 1 wei will give you 1 unit, or 0.001 TOK.
    /// @notice The below rate works out to about 1.2HUB / 1USDC
    uint256 private _rate; // rate is 2e3 => 1 wei = 0.0000000000000002 HUB 

    address public constant UNIVERSAL_ROUTER_ADDRESS = 0xEf1c6E67703c7BD7107eed8303Fbe6EC2554BF6B;
    address public constant PERMIT2_ADDRESS = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    IUniversalRouter public universalRouter;
    Permit2 public immutable permit2;

    struct Token {
        address tokenAddress;
        uint24 poolFee;
        bool approved;
    }

    mapping(address => uint256) public userHubBalance;
    mapping(address => Token) private approvedTokens;

    /*------EVENTS------*/

    event HubBought(address indexed buyer, uint256 indexed amount, uint256 indexed hubBought);
    event TokenAdded(address indexed tokenAddress, uint24 indexed poolFee);
    event TokenRemoved(address indexed tokenAddress);

    /*------CONSTRUCTOR------*/

    constructor() {
        universalRouter = IUniversalRouter(UNIVERSAL_ROUTER_ADDRESS);
        permit2 = Permit2(PERMIT2_ADDRESS);
        _rate = 2e3;
    }

    /*------STATE CHANGING FUNCTIONS------*/

    /// @notice Allows a user to purchase HUB using approve on _purchaseToken.
    /// @param _purchaseToken the address of the ERC20 token used to buy HUB
    /// @param _amount the the _amount of _purchaseToken that the user is willing to spend
    /// @param _slippage the minimum _amount of weth that _purchaseToken will be swapped for. Called off-chain using uniswap quoter
    function buyHubWithApproval(
        address _purchaseToken,
        uint256 _amount,
        uint256 _slippage
        ) public returns(uint256) {

        Token memory token = approvedTokens[_purchaseToken];

        _validatePurchase(_amount, msg.sender, token);

        IERC20(token.tokenAddress).transferFrom(msg.sender, address(this), _amount);

        uint256 hubBought = _buyHub(msg.sender, _amount, token.tokenAddress, token.poolFee, _slippage, block.timestamp + 60);

        emit HubBought(msg.sender, _amount, hubBought);

        return (hubBought);
    }

    /// @notice Allows a user to purchase HUB using permit2. This lets a 3rd party pay for gas.
    /// @param _purchaseToken the address of the ERC20 token used to buy HUB
    /// @param _sender the sender of the permit on whose behalf the tx will be executed.
    /// @param _amount the _amount of _purchaseToken that the user is willing to spend
    /// @param _slippage the minimum _amount of weth that _purchaseToken will be swapped for. Called off-chain using uniswap quoter
    /// @param _nonce the permit nonce.
    /// @param _deadline the permit deadline after which it will be invalid.
    /// @param _signature the signature of the _sender over the permit.
    /// @return returns the amount oh HUB bought by the user. 
    function buyHubWithPermit(
            address _purchaseToken,
            address _sender,
            uint256 _amount,
            uint256 _slippage,
            uint256 _nonce,
            uint256 _deadline,
            bytes calldata _signature
        ) public returns(uint256) {  
        
        require(_sender != address(0), "Address 0");  
        
        Token memory token = approvedTokens[_purchaseToken];

        _validatePurchase(_amount, _sender, token);

        // Transfer tokens from _sender to ourselves.
        permit2.permitTransferFrom(
            // The permit message.
            ISignatureTransfer.PermitTransferFrom({
                permitted: ISignatureTransfer.TokenPermissions({
                    token: _purchaseToken,
                    amount: _amount
                }),
                nonce: _nonce,
                deadline: _deadline
            }),
            // The transfer recipient and amount.
            ISignatureTransfer.SignatureTransferDetails({
                to: address(this),
                requestedAmount: _amount
            }),
            // The owner of the tokens, which must also be
            // the signer of the message, otherwise this call
            // will fail.
            _sender,
            // The packed signature that was the result of signing
            // the EIP712 hash of `permit`.
            _signature
        );

        uint256 hubBought = _buyHub(_sender, _amount, token.tokenAddress, token.poolFee, _slippage, _deadline);
        
        emit HubBought(_sender, _amount, hubBought);

        return (hubBought);
    }

    ///@notice allows the owner to add ERC20 tokens to use for purchasing HUB. Approves the Permit2 contract to transfer the token. 
    ///@param _tokenAddress the address of the token being added.
    ///@param _poolFee the pool fee for the corresponding token/WETH pool on UniswapV3.
    function approveToken(address _tokenAddress, uint24 _poolFee) public onlyOwner {
        require(_tokenAddress != address(0), "Address 0");
        require(_poolFee == 1000 || _poolFee == 3000 || _poolFee == 5000, "Invalid Pool Fee");
        
        approvedTokens[_tokenAddress] = Token({
            tokenAddress: _tokenAddress,
            poolFee: _poolFee,
            approved: true
        });

        IERC20(_tokenAddress).approve(PERMIT2_ADDRESS, type(uint256).max);
        permit2.approve(_tokenAddress, address(universalRouter), type(uint160).max, type(uint48).max);

        emit TokenAdded(_tokenAddress, _poolFee);
    }

    ///@notice sets the approved flag in the Token struct to false.
    ///@param _tokenAddress the address of the ERC20 token to remove.
    function removeToken(address _tokenAddress) public onlyOwner {
        Token storage token = approvedTokens[_tokenAddress];
        token.approved = false;

        emit TokenRemoved(_tokenAddress);
    }

     /*------INTERNAL FUNCTIONS------*/

    /// @notice swapExactInputSingle swaps a fixed amount of _token for a maximum possible amount of WETH
    /// @dev The calling address must approve this contract to spend at least `amountIn` worth of _token for this function to succeed.
    /// @param _amountIn The exact amount of _token that will be swapped for WETH.
    /// @param _token The address of the token to be swapped.
    /// @param _amountOutMinimum The minimum amount of _token to receive after the swap.
    /// @param _deadline The timestamp after which the transaction becomes invalid.
    function _swapExactInputSingle(
        uint256 _amountIn,
        address _token,
        uint24 _poolFee,
        uint256 _amountOutMinimum,
        uint256 _deadline
    ) internal returns(uint256) {
        // Build uniswap commands
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V3_SWAP_EXACT_IN)));
        // Create path for the swap
        bytes memory path = abi.encodePacked(_token, _poolFee, WETH);
        // Create input parameters for execution with commands
        bytes[] memory inputs = new bytes[](1); 
        inputs[0] = abi.encode(Constants.MSG_SENDER, _amountIn, _amountOutMinimum, path, true); 

        uint256 wethBalanceBefore = _getBalance();
        // Execute the swap
        universalRouter.execute(commands, inputs, _deadline);

        uint256 wethBalanceAfter = _getBalance();
        // Calculate amount of Weth swapped
        uint256 wethOut = wethBalanceAfter - wethBalanceBefore;
        //Update contract weth balance
        balance += wethOut;

        return wethOut;
    }

    function _buyHub(
        address _sender,
        uint256 _amount,
        address _purchaseToken,
        uint24 _poolFee,
        uint256 _slippage,
        uint256 _deadline
        ) internal returns(uint256 hubBought) {
            uint256 wethOut = _swapExactInputSingle(_amount, _purchaseToken, _poolFee, _slippage, _deadline);
            balance += wethOut;
            hubBought =  _getHub(wethOut);
            userHubBalance[_sender] += hubBought;
    }

    function _getHub(uint256 _weiAmount) internal view returns(uint256) {
        return _weiAmount * _rate;
    }

    function _getBalance() internal view returns(uint256 balance) {
        balance = IERC20(WETH).balanceOf(address(this));
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

    function _validatePurchase(uint256 _amount, address _sender, Token memory _token) internal view {
        require(_amount > 0, "Cannot Buy 0");
        require(_token.approved == true, "Not Approved Token");
        IERC20 token_ = IERC20(_token.tokenAddress);
        require(token_.balanceOf(_sender) >= _amount, "Insufficient Balance");
        
    }

}
