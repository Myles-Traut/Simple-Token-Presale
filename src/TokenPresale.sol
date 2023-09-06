// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "lib/universal-router/contracts/interfaces/IUniversalRouter.sol";
import "lib/universal-router/contracts/libraries/Constants.sol";
import "lib/universal-router/contracts/libraries/Commands.sol";

contract TokenPresale {
    // sell users HUB tokens based on a rate vs USDC. 1 HUB = 0.5 USDC
    // Users are able to purchase HUB in various currencies
    // User balances are kept in a mapping and HUB becomes claimable after launch
    // Deposited currencies are swapped for ETH via the uniswap UR and stored in a balance var.
    // Profits are only withdrawable by the contact owner

    uint256 public balance;

    // How many token units a buyer gets per wei.
    // The rate is the conversion between wei and the smallest and indivisible token unit.
    // So, if you are using a rate of 1 with a ERC20Detailed token with 3 decimals called TOK
    // 1 wei will give you 1 unit, or 0.001 TOK.
    uint256 private _rate; // rate is 1e6 => 1 wei = 0.000000000001 HUB

    // Amount of wei raised
    uint256 private _weiRaised;

    address public constant UNIVERSAL_ROUTER_ADDRESS = 0xEf1c6E67703c7BD7107eed8303Fbe6EC2554BF6B;
    address public constant PERMIT2_ADDRESS = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address public constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    IUniversalRouter public universalRouter;
    IPermit2 public immutable permit2;

    mapping(address user => uint256 hubBalance) public userHubBalance;

    constructor() {
        universalRouter = IUniversalRouter(UNIVERSAL_ROUTER_ADDRESS);
        permit2 = IPermit2(PERMIT2_ADDRESS);
        _rate = 1e6;
    }

    /// @param purchaseToken the address of the ERC20 token used to buy HUB
    /// @param amount the the amount of purchaseToken that the user is willing to spend
    /// @param slippage the minimum amount of eth that purchaseToken will be swapped for.
        // Called off-chain using uniswap quoter
    function buyHub(address purchaseToken, uint256 amount, uint256 slippage) public returns(uint256) {
        //Swap purchaseToken to ETH
        permit2.approve(purchaseToken, address(universalRouter), uint160(amount), type(uint48).max);
        balanace += _swapExactInputSingle(amount, purchaseToken, slippage, block.timestamp + 60);

        return balance;
        //hubBought = weiAmount * _rate;
    }

    /// @notice swapExactInputSingle swaps a fixed amount of _token0 for a maximum possible amount of _token1
    /// @dev The calling address must approve this contract to spend at least `amountIn` worth of _token0 for this function to succeed.
    /// @param _amountIn The exact amount of _token that will be swapped for _token1.
    function _swapExactInputSingle(
        uint256 _amountIn,
        address _token,
        uint256 _amountOutMinimum,
        uint256 _deadline
    ) internal {

        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V3_SWAP_EXACT_IN)));
        bytes memory path = abi.encodePacked(_token, poolFee, Constants.ETH);
        bytes[] memory inputs = new bytes[](1); 
        inputs[0] = abi.encode(Constants.MSG_SENDER, _amountIn, _amountOutMinimum, path, true); 

        universalRouter.execute(commands, inputs, _deadline);
    }

}
