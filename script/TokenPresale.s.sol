// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {Script, console2} from "lib/forge-std/src/Script.sol";
import {TokenPresale} from "../src/TokenPresale.sol";

// Deployed addr : 0xD055B32fd3136F1dCA638Cd8f4B2eAF4A10abAb3

contract TokenPresaleScript is Script {

    TokenPresale public tokenPresale;

    function run() public {
        uint256 deployerPrivate_Key = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivate_Key);
        
        tokenPresale = new TokenPresale();

        vm.stopBroadcast();
    }
}
