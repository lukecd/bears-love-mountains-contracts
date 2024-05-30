// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {BearsLoveDefi} from "../src/BearsLoveDefi.sol";

contract SetNftContract is Script {
    function run() external {
        bool broadcast = vm.envBool("BROADCAST");
        address defiAddress = vm.envAddress("DEFI_CONTRACT_ADDRESS");
        address nftAddress = vm.envAddress("BM_CONTRACT_ADDRESS");

        if (broadcast) {
            vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        }

        BearsLoveDefi defiContract = BearsLoveDefi(payable(defiAddress));
        defiContract.setNftContract(nftAddress);

        if (broadcast) {
            vm.stopBroadcast();
        }
    }
}
