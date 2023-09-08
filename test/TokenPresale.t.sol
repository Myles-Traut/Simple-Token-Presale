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
import "lib/universal-router/permit2/src/interfaces/ISignatureTransfer.sol";
import {PermitHash} from "lib/universal-router/permit2/src/libraries/PermitHash.sol";

contract TokenPresaleTest is Test {
    TokenPresale public tokenPresale;

    uint256 public aliceKey;
    uint256 public chadKey;

    address public alice;
    address public bob;
    address public chad;
    address public owner;
    
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; 
    address public constant UNI = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;

    address public constant PERMIT2_ADDRESS = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address public constant UNIVERSAL_ROUTER_ADDRESS = 0xEf1c6E67703c7BD7107eed8303Fbe6EC2554BF6B;
    IQuoter public constant quoter = IQuoter(0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6);

    IERC20 public usdc;
    IERC20 public weth;

    IUniversalRouter public universalRouter;
    Permit2 public permit2;

    event HubBought(address indexed buyer, uint256 indexed amount, uint256 indexed hubBought);

    function setUp() public {
        (alice, aliceKey) = makeAddrAndKey("alice");
        (chad, chadKey) = makeAddrAndKey("chad");
        bob = vm.addr(2);
        owner = vm.addr(3);

        usdc = IERC20(USDC);
        weth = IERC20(WETH);

        universalRouter = IUniversalRouter(UNIVERSAL_ROUTER_ADDRESS);
        permit2 = Permit2(PERMIT2_ADDRESS);

        vm.prank(owner);
            tokenPresale = new TokenPresale();

        deal(address(usdc), alice, 100 ether);
        deal(UNI, alice, 1e17);
        deal(address(usdc), bob, 10 ether);
        deal(address(usdc), chad, 10 ether);

        vm.startPrank(owner);
            tokenPresale.approveToken(address(usdc), uint24(3000));
        vm.stopPrank();

        vm.startPrank(alice);
            usdc.approve(PERMIT2_ADDRESS, type(uint256).max);
            usdc.approve(address(tokenPresale), type(uint256).max);
        vm.stopPrank();

         vm.startPrank(bob);
            usdc.approve(PERMIT2_ADDRESS, type(uint256).max);
            usdc.approve(address(tokenPresale), type(uint256).max);
        vm.stopPrank();

        ///@notice Chad only has to approve the permit2 contract because he's using a signed permit.
        vm.prank(chad);
            usdc.approve(PERMIT2_ADDRESS, type(uint256).max);
    }

    function test_BuyHubWithApproval() public {
        vm.startPrank(alice);
            assertEq(tokenPresale.userHubBalance(msg.sender), 0);
            // Get off-chain quote for 1USDC => WETH
            uint256 quote = _quote(1e6, address(usdc));
            assertEq(tokenPresale.balance(), 0);

            uint256 hubQuote = tokenPresale.getHubQuote(quote);
            uint256 hubBought = tokenPresale.buyHubWithApproval(address(usdc), 1e6, quote);
            assertGe(tokenPresale.balance(), quote);
            assertEq(hubBought, hubQuote);
            assertEq(tokenPresale.userHubBalance(alice), hubBought);

            quote = _quote(1e6, address(usdc));
            uint256 aliceBalBefore = tokenPresale.userHubBalance(alice);
            uint256 presaleBalBefore = tokenPresale.balance();
            hubQuote = tokenPresale.getHubQuote(quote);
            hubBought = tokenPresale.buyHubWithApproval(address(usdc), 1e6, quote);
            uint256 aliceBalAfter = tokenPresale.userHubBalance(alice);
            uint256 presaleBalAfter = tokenPresale.balance();

            assertGe(presaleBalAfter, presaleBalBefore + quote);
            assertEq(aliceBalAfter, aliceBalBefore + hubQuote);
        vm.stopPrank();

        vm.startPrank(bob);
            quote = _quote(2e6, address(usdc));
            presaleBalBefore = tokenPresale.balance();
            hubQuote = tokenPresale.getHubQuote(quote);
            hubBought = tokenPresale.buyHubWithApproval(address(usdc), 2e6, quote);
            presaleBalAfter = tokenPresale.balance();
            
            assertEq(hubQuote, hubBought);
            assertGe(presaleBalAfter, presaleBalBefore + quote);
            assertEq(tokenPresale.userHubBalance(bob), hubBought);
        vm.stopPrank();
    }

    function test_BuyHubWithPermit() public {
        uint256 quote = _quote(1e6, address(usdc));

        Permit2.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({
                token: address(usdc),
                amount: 1e6
            }),
            nonce: 0,
            deadline: block.timestamp + 60
        });

        bytes memory signature = _signPermit(permit, address(tokenPresale), chadKey);

        assertEq(tokenPresale.userHubBalance(chad), 0);
        assertEq(IERC20(WETH).balanceOf(address(tokenPresale)), 0);

        vm.prank(owner);
            uint256 hubBought = tokenPresale.buyHubWithPermit(
                address(usdc),
                chad,
                1e6,
                quote,
                permit.nonce,
                permit.deadline,
                signature
            );
        assertEq(tokenPresale.userHubBalance(chad), hubBought);
        assertGe(IERC20(WETH).balanceOf(address(tokenPresale)), quote);
    }

    function test_Reverts() public {
        vm.startPrank(alice);

            uint256 quote = _quote(1e6, address(usdc));

            vm.expectRevert("Cannot Buy 0");
            tokenPresale.buyHubWithApproval(address(usdc), 0, quote);
            
            uint256 uniQuote = _quote(1e18, UNI);
            
            vm.expectRevert("Not Approved Token");
            tokenPresale.buyHubWithApproval(UNI, 1e18, uniQuote);

            quote = _quote(500e6, address(usdc));

            vm.expectRevert("Insufficient Balance");
            tokenPresale.buyHubWithApproval(address(usdc), 500 ether, quote);
        vm.stopPrank();        
    }

    function test_EventHubBought() public {
        vm.startPrank(alice);
            uint256 quote = _quote(1e6, address(usdc));
            vm.expectEmit(true, true, true, true);
            emit HubBought(alice, 1e6, tokenPresale.getHubQuote(quote));
            tokenPresale.buyHubWithApproval(address(usdc), 1e6, quote);
    }

    function _quote(uint256 _amount, address _token) internal returns (uint256 amountOutQuote) {
        amountOutQuote = quoter.quoteExactInputSingle(_token, address(weth), 3000, _amount, 0);
    }

    // Generate a signature for a permit message.
    function _signPermit(
        Permit2.PermitTransferFrom memory permit,
        address spender,
        uint256 signerKey
    ) internal view returns (bytes memory signature) {

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, _getEIP712Hash(permit, spender));
        signature = abi.encodePacked(r, s, v);
    }

    // Compute the EIP712 hash of the permit object.
    // Normally this would be implemented off-chain.
    function _getEIP712Hash(Permit2.PermitTransferFrom memory permit, address spender)
        internal
        view
        returns (bytes32 h) {

        return keccak256(abi.encodePacked(
            "\x19\x01",
            permit2.DOMAIN_SEPARATOR(),
            keccak256(abi.encode(
                PermitHash._PERMIT_TRANSFER_FROM_TYPEHASH,
                keccak256(abi.encode(
                    PermitHash._TOKEN_PERMISSIONS_TYPEHASH,
                    permit.permitted.token,
                    permit.permitted.amount
                )),
                spender,
                permit.nonce,
                permit.deadline
            ))
        ));
    }
}
