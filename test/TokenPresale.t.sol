// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {Test, console} from "forge-std/Test.sol";
import {TokenPresale} from "../src/TokenPresale.sol";

contract TokenPresaleTest is Test {
    TokenPresale public tokenPresale;

    address public alice;
    address public bob;
    address public owner;

    event HubBought(address indexed buyer, uint256 indexed ethSpent, uint256 indexed hubBought);

    function setUp() public {
        
        owner = vm.addr(1);
        bob = vm.addr(2);
        alice = vm.addr(3);

        vm.prank(owner);
            tokenPresale = new TokenPresale();

        deal(alice, 10 ether);
    }

    function test_BuyHub() public {
        vm.startPrank(alice);
            assertEq(tokenPresale.userHubBalance(alice), 0);

            uint256 hubQuote = tokenPresale.getHubQuote(1 ether);
            uint256 hubBought = tokenPresale.buyHub{value: 1 ether}(alice);

            assertGe(tokenPresale.balance(), 1 ether);
            assertEq(hubBought, hubQuote);
            assertEq(tokenPresale.userHubBalance(alice), hubBought);
        vm.stopPrank();
    }

    function test_WithdawEth() public {
        vm.startPrank(alice);
            assertEq(tokenPresale.balance(), 0 ether);
            tokenPresale.buyHub{value: 1 ether}(alice);
            assertEq(tokenPresale.balance(), 1 ether);
        vm.stopPrank();

        vm.startPrank(owner);
            assertEq(owner.balance, 0 ether);
            tokenPresale.withdrawETH(0.5 ether);
            assertEq(owner.balance, 0.5 ether);
            assertEq(tokenPresale.balance(), 0.5 ether);
        vm.stopPrank();
    }

    function test_EventHubBought() public {
        vm.startPrank(alice);
            vm.expectEmit(true, true, true, true);
            emit HubBought(alice, 1 ether, tokenPresale.getHubQuote(1 ether));
            tokenPresale.buyHub{value: 1 ether}(alice);
        vm.stopPrank();
    }
}
