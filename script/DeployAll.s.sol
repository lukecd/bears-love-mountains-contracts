// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {BearsLoveMemes} from "../src/BearsLoveMemes.sol";
import {BearsLoveDefi} from "../src/BearsLoveDefi.sol";
import {BearsLoveMountains} from "../src/BearsLoveMountains.sol";

contract DeployAll is Script {
    function run()
        external
        returns (BearsLoveMountains, BearsLoveMemes, BearsLoveDefi)
    {
        bool broadcast = vm.envBool("BROADCAST");
        broadcast = true;
        if (broadcast) {
            vm.startBroadcast();
        }

        // Deploy BearsLoveMemes contract
        BearsLoveMemes memeToken = new BearsLoveMemes(
            "Bears Love Memes",
            "BMEME"
        );

        // Deploy BearsLoveDefi contract
        BearsLoveDefi defiContract = new BearsLoveDefi(
            address(memeToken),
            address(0), // Temporary placeholder for mountains contract
            0.69 ether // Threshold for buying meme tokens
        );

        // Deploy BearsLoveMountains contract
        BearsLoveMountains mountainsToken = new BearsLoveMountains(
            "Bears Love Mountains",
            "MNTN",
            0.001 ether,
            address(defiContract) // Pass the defiContract as the rewards contract
        );

        // Set the nftContract in defiContract
        defiContract.setNftContract(address(mountainsToken));

        // Set owners for contracts
        memeToken.transferOwnership(msg.sender);
        defiContract.transferOwnership(msg.sender);
        mountainsToken.transferOwnership(msg.sender);

        if (broadcast) {
            vm.stopBroadcast();
        }

        return (mountainsToken, memeToken, defiContract);
    }
}
