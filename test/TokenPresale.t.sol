// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {Test, console} from "forge-std/Test.sol";
import {TokenPresale} from "../src/TokenPresale.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "lib/v3-periphery/contracts/interfaces/IQuoter.sol";

import "lib/universal-router/contracts/interfaces/IUniversalRouter.sol";
import "lib/universal-router/contracts/libraries/Constants.sol";
import "lib/universal-router/contracts/libraries/Commands.sol";
import "lib/universal-router/permit2/src/Permit2.sol";

contract TokenPresaleTest is Test {
    TokenPresale public tokenPresale;

    address public alice;
    
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; 
    address public constant PERMIT2_ADDRESS = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address public constant UNIVERSAL_ROUTER_ADDRESS = 0xEf1c6E67703c7BD7107eed8303Fbe6EC2554BF6B;
    IQuoter public constant quoter = IQuoter(0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6);

    IERC20 public usdc;
    IERC20 public weth;

    IUniversalRouter public universalRouter;
    Permit2 public permit2;

    function setUp() public {
        usdc = IERC20(USDC);
        weth = IERC20(WETH);
        tokenPresale = new TokenPresale();
        universalRouter = IUniversalRouter(UNIVERSAL_ROUTER_ADDRESS);
        permit2 = Permit2(PERMIT2_ADDRESS);

        alice = vm.addr(1);
        deal(alice, 1 ether);
        deal(address(usdc), alice, 10 ether);

        vm.startPrank(alice);
            weth.approve(PERMIT2_ADDRESS, type(uint256).max);
            usdc.approve(PERMIT2_ADDRESS, type(uint256).max);
            permit2.approve(address(usdc), address(universalRouter), type(uint160).max, type(uint48).max);
            permit2.approve(address(weth), address(universalRouter), type(uint160).max, type(uint48).max);

            usdc.approve(address(tokenPresale), 100 ether);
            weth.approve(address(tokenPresale), 100 ether);
        vm.stopPrank();

        vm.prank(address(tokenPresale));
            usdc.approve(PERMIT2_ADDRESS, type(uint256).max);
    }

    function test_BuyHub() public {
        // uint256 hubBought;

        vm.startPrank(alice);
            uint256 quote = _quote(1650e6);
            console.log("Quote", quote);
            uint256 ethInContract = tokenPresale.buyHub(address(usdc), 1650e6, quote);
            console.logUint(ethInContract);
    }

    function _quote(uint256 _amount) internal returns (uint256 amountOutQuote) {
        amountOutQuote = quoter.quoteExactInputSingle(address(usdc), address(weth), 3000, _amount, 0);
    }
}
