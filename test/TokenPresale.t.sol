// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {TokenPresale} from "../src/TokenPresale.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "lib/v3-periphery/contracts/interfaces/IQuoter.sol";

contract TokenPresaleTest is Test {
    TokenPresale public tokenPresale;

    address public alice;

    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; 
    address public constant PERMIT2_ADDRESS = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    IQuoter public constant quoter = IQuoter(0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6);

    IERC20 public usdc;

    function setUp() public {
        usdc = IERC20(USDC);
        tokenPresale = new TokenPresale();

        alice = vm.addr(1);
        deal(alice, 1 ether);
        deal(address(usdc), alice, 10 ether);

        vm.startPrank(alice);
            usdc.approve(PERMIT2_ADDRESS, type(uint256).max);
        vm.stopPrank();
    }

    function test_BuyHub() public {
        uint256 hubBought;

        vm.prank(alice);
            ethInContract = tokenPresale.buyHub(address(usdc), 1 ether, );
            console.logUint(hubBought);
    }

    function _quote(uint256 _amount) internal returns (uint256 amountOutQuote) {
        amountOutQuote = quoter.quoteExactInputSingle(address(uni), address(usdc), 3000, _amount, 0);
    }
}
