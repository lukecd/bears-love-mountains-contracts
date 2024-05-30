// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {console2} from "forge-std/console2.sol";
import {BearsLoveMountains} from "../src/BearsLoveMountains.sol";
import {BearsLoveDefi} from "../src/BearsLoveDefi.sol";
import {BearsLoveMemes} from "../src/BearsLoveMemes.sol";
import {DeployAll} from "../script/DeployAll.s.sol";

contract BearsLoveMountainsTest is Test {
    BearsLoveMountains blm;
    BearsLoveMemes memeContract;
    BearsLoveDefi rewardsContract;

    address owner = address(1);
    address user = address(2);
    address holder = address(3);

    function setUp() public {
        vm.startPrank(owner);
        DeployAll deployScript = new DeployAll();
        (blm, memeContract, rewardsContract) = deployScript.run();
        vm.stopPrank();
    }

    function testMintNFTs() public {
        vm.startPrank(user);

        uint256 tokenId = 1;
        uint256 amount = 1;
        uint256 maxTokenId = blm.MAX_TOKEN_ID();
        uint256 price = blm.getPrice(tokenId, amount, true);
        // console.log("Initial price:", price); //toEther(price));

        vm.deal(user, 1 ether);
        vm.expectRevert(BearsLoveMountains.InsufficientPayment.selector);
        blm.mint{value: 0.00001 ether}(tokenId, amount);

        // Expect the custom TokenIdExceedsMaximum error
        vm.expectRevert(BearsLoveMountains.TokenIdExceedsMaximum.selector);
        blm.mint{value: price}(maxTokenId + 1, amount);

        // This should pass
        blm.mint{value: price}(tokenId, amount);
        assertEq(blm.circulatingSupply(tokenId), amount);

        vm.stopPrank();
    }

    function testPriceIncreasesOnMintNFTs() public {
        vm.startPrank(user);

        uint256 tokenId = 1;
        uint256 amount = 1;

        vm.deal(user, 10000 ether); // Provide sufficient funds for multiple mints

        uint256 previousPrice = blm.getPrice(tokenId, amount, true);
        writeCSVLine("mint_count,price");
        writeCSVLine(
            string(
                abi.encodePacked(uintToStr(1), ",", uintToStr(previousPrice))
            )
        );

        blm.mint{value: previousPrice}(tokenId, amount);
        uint256 numberToMint = 1000;
        for (uint256 i = 1; i < numberToMint; i++) {
            uint256 currentPrice = blm.getPrice(tokenId, amount, true);
            assertTrue(
                currentPrice > previousPrice,
                "Price did not increase as expected"
            );

            writeCSVLine(
                string(
                    abi.encodePacked(uintToStr(i), ",", uintToStr(currentPrice))
                )
            );

            blm.mint{value: currentPrice}(tokenId, amount);
            previousPrice = currentPrice;
        }

        assertEq(blm.circulatingSupply(tokenId), numberToMint);

        vm.stopPrank();
    }

    function testBurnNFTs() public {
        uint256 tokenId = 1;
        uint256 amountToMint = 10;
        uint256 amountToBurn = 5;

        vm.startPrank(user);
        vm.deal(user, 1 ether);

        // First mint some
        uint256 curSupply = blm.circulatingSupply(tokenId);
        for (uint256 i = 1; i < amountToMint; i++) {
            uint256 price = blm.getPrice(tokenId, 1, true);
            blm.mint{value: price}(tokenId, 1);
            curSupply++;
            assertEq(blm.circulatingSupply(tokenId), curSupply);
        }

        // Then burn half
        for (uint256 i = 1; i < amountToBurn; i++) {
            blm.burn(tokenId, 1);
            curSupply--;
            assertEq(blm.circulatingSupply(tokenId), curSupply);
        }
        assertEq(blm.circulatingSupply(tokenId), amountToMint - amountToBurn);

        vm.stopPrank();
    }

    function testBurnSomeoneElsesNFTs() public {
        uint256 tokenId = 1;
        vm.startPrank(user);
        vm.deal(user, 1 ether);
        uint256 price = blm.getPrice(tokenId, 1, true);
        blm.mint{value: price}(tokenId, 1);
        vm.stopPrank();

        vm.startPrank(holder);
        vm.deal(user, 1 ether);
        vm.expectRevert(BearsLoveMountains.InsufficientBalance.selector);
        blm.burn(tokenId, 1);
        vm.stopPrank();
    }

    /** 																UTILITY FUNCTIONS												 */
    function writeCSVLine(string memory line) internal {
        bytes memory lineBytes = bytes(line);
        vm.writeLine("output.csv", string(abi.encodePacked(lineBytes)));
    }

    function uintToStr(
        uint256 _i
    ) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
}
