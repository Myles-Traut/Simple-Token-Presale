// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "lib/universal-router/contracts/interfaces/IUniversalRouter.sol";

contract TokenPresale {
    // sell users HUB tokens based on a rate vs ETH.
    // Users are able to purchase HUB in various currencies
    // User balances are kept in a mapping and HUB becomes claimable after launch
    // Deposited currencies are swapped for ETH via the uniswap UR and stored in a balance var.
    // Profits are only withdrawable by the contact owner

    uint256 public balance;

    address public constant UNIVERSAL_ROUTER = 0xEf1c6E67703c7BD7107eed8303Fbe6EC2554BF6B;

    mapping(address user => uint256 hubBalance) public userHubBalance;

    constructor() {}

}
