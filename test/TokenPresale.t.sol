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
    address public bob;
    
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; 
    address public constant PERMIT2_ADDRESS = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address public constant UNIVERSAL_ROUTER_ADDRESS = 0xEf1c6E67703c7BD7107eed8303Fbe6EC2554BF6B;
    IQuoter public constant quoter = IQuoter(0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6);

    IERC20 public usdc;
    IERC20 public weth;

    IUniversalRouter public universalRouter;
    Permit2 public permit2;

    event HubBought(address indexed buyer, uint256 indexed amount, uint256 indexed hubBought);

    function setUp() public {
        usdc = IERC20(USDC);
        weth = IERC20(WETH);
        tokenPresale = new TokenPresale();
        universalRouter = IUniversalRouter(UNIVERSAL_ROUTER_ADDRESS);
        permit2 = Permit2(PERMIT2_ADDRESS);

        alice = vm.addr(1);
        bob = vm.addr(2);

        deal(address(usdc), alice, 100 ether);
        deal(address(usdc), bob, 10 ether);

        vm.startPrank(alice);
            usdc.approve(PERMIT2_ADDRESS, type(uint256).max);
            permit2.approve(address(usdc), address(universalRouter), type(uint160).max, type(uint48).max);
            usdc.approve(address(tokenPresale), 100 ether);
        vm.stopPrank();

         vm.startPrank(bob);
            usdc.approve(PERMIT2_ADDRESS, type(uint256).max);
            permit2.approve(address(usdc), address(universalRouter), type(uint160).max, type(uint48).max);
            usdc.approve(address(tokenPresale), 100 ether);
        vm.stopPrank();

    }

    function test_BuyHub() public {
        vm.startPrank(alice);
            assertEq(tokenPresale.userHubBalance(msg.sender), 0);
            // Get off-chain quote for 1USDC => WETH
            uint256 quote = _quote(1e6);
            assertEq(tokenPresale.balance(), 0);

            uint256 hubQuote = tokenPresale.getHubQuote(quote);
            uint256 hubBought = tokenPresale.buyHub(address(usdc), 1e6, quote);
            assertGe(tokenPresale.balance(), quote);
            assertEq(hubBought, hubQuote);
            assertEq(tokenPresale.userHubBalance(alice), hubBought);

            quote = _quote(1e6);
            uint256 aliceBalBefore = tokenPresale.userHubBalance(alice);
            uint256 presaleBalBefore = tokenPresale.balance();
            hubQuote = tokenPresale.getHubQuote(quote);
            hubBought = tokenPresale.buyHub(address(usdc), 1e6, quote);
            uint256 aliceBalAfter = tokenPresale.userHubBalance(alice);
            uint256 presaleBalAfter = tokenPresale.balance();

            assertGe(presaleBalAfter, presaleBalBefore + quote);
            assertEq(aliceBalAfter, aliceBalBefore + hubQuote);
        vm.stopPrank();

        vm.startPrank(bob);
            quote = _quote(2e6);
            presaleBalBefore = tokenPresale.balance();
            hubQuote = tokenPresale.getHubQuote(quote);
            hubBought = tokenPresale.buyHub(address(usdc), 2e6, quote);
            presaleBalAfter = tokenPresale.balance();
            
            assertEq(hubQuote, hubBought);
            assertGe(presaleBalAfter, presaleBalBefore + quote);
            assertEq(tokenPresale.userHubBalance(bob), hubBought);
        vm.stopPrank();
    }

    function test_EventHubBought() public {
        vm.startPrank(alice);
            uint256 quote = _quote(1e6);
            vm.expectEmit(true, true, true, true);
            emit HubBought(alice, 1e6, tokenPresale.getHubQuote(quote));
            tokenPresale.buyHub(address(usdc), 1e6, quote);
    }

    function _quote(uint256 _amount) internal returns (uint256 amountOutQuote) {
        amountOutQuote = quoter.quoteExactInputSingle(address(usdc), address(weth), 3000, _amount, 0);
    }
}
