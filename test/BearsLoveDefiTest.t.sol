// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {BearsLoveMemes} from "../src/BearsLoveMemes.sol";
import {BearsLoveDefi} from "../src/BearsLoveDefi.sol";
import {BearsLoveMountains} from "../src/BearsLoveMountains.sol";
import {DeployAll} from "../script/DeployAll.s.sol";
import {console} from "forge-std/console.sol";

contract BearsLoveDefiTest is Test {
    BearsLoveMemes memeContract;
    BearsLoveDefi defiContract;
    BearsLoveMountains nftContract;
    address owner = address(1);
    address user = address(2);

    uint256 threshold = 1 ether;

    function setUp() public {
        vm.startPrank(owner);
        DeployAll deployScript = new DeployAll();
        (nftContract, memeContract, defiContract) = deployScript.run();
        vm.stopPrank();
    }

    function testReceiveETHBelowThreshold() public {
        vm.deal(user, 0.5 ether);

        vm.prank(user);
        (bool sent, ) = address(defiContract).call{value: 0.5 ether}("");
        assertTrue(sent);
        assertEq(address(defiContract).balance, 0.5 ether);

        // Verify no meme tokens were minted
        assertEq(memeContract.balanceOf(address(defiContract)), 0);
    }

    function testReceiveETHAboveThreshold() public {
        vm.deal(user, 1.5 ether);

        vm.prank(user);
        (bool sent, ) = address(defiContract).call{value: 1.5 ether}("");
        assertTrue(sent);

        // Verify meme tokens were minted
        uint256 memeBalance = memeContract.balanceOf(address(defiContract));
        assertGt(memeBalance, 0);

        // Verify contract balance is zero after purchase
        assertEq(address(defiContract).balance, 0);
    }

    function testMintNFTUpdatesTotals() public {
        vm.startPrank(user);

        uint256 tokenId = 1;
        uint256 amount = 5;

        // Mint NFTs to the user
        uint256 price = nftContract.getPrice(tokenId, amount, true);
        vm.deal(user, 1 ether);
        nftContract.mint{value: price}(tokenId, amount);

        // Verify total circulation and user's holdings in the DeFi contract
        assertEq(defiContract.nftHoldings(user), amount);
        assertEq(defiContract.totalCirculation(), amount);

        vm.stopPrank();
    }

    function testBurnNFTUpdatesTotals() public {
        vm.startPrank(user);

        uint256 tokenId = 1;
        uint256 amount = 5;

        // Mint NFTs to the user
        uint256 price = nftContract.getPrice(tokenId, amount, true);
        vm.deal(user, 1 ether);
        nftContract.mint{value: price}(tokenId, amount);

        // Burn NFTs
        nftContract.burn(tokenId, amount);

        // Verify total circulation and user's holdings in the DeFi contract
        assertEq(defiContract.nftHoldings(user), 0);
        assertEq(defiContract.totalCirculation(), 0);

        vm.stopPrank();
    }

    receive() external payable {} // To receive Ether during tests
}
