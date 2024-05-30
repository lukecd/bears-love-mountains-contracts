// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {BearsLoveMemes} from "../src/BearsLoveMemes.sol";
import {console} from "forge-std/console.sol";
import {DeployAll} from "../script/DeployAll.s.sol";

contract BearsLoveMemesTest is Test {
    BearsLoveMemes memeContract;
    address owner = address(1);
    address user = address(2);

    function setUp() public {
        vm.startPrank(owner);
        DeployAll deployScript = new DeployAll();
        (, memeContract, ) = deployScript.run();
        vm.stopPrank();
    }

    function testMint() public {
        vm.startPrank(user);
        uint256 amount = 1;
        uint256 price = memeContract.getPrice(amount);
        vm.deal(user, 1 ether);
        vm.expectRevert(BearsLoveMemes.InsufficientPayment.selector);
        memeContract.mint{value: 0.00001 ether}(amount);

        memeContract.mint{value: price}(amount);
        assertEq(memeContract.balanceOf(user), amount);
        vm.stopPrank();
    }

    function testBurnMemeCoins() public {
        vm.startPrank(user);
        uint256 amount = 1;
        uint256 price = memeContract.getPrice(amount);

        vm.deal(user, 1 ether);
        memeContract.mint{value: price}(amount);
        assertEq(memeContract.balanceOf(user), amount);

        // Price changes post-mint, check again before computing estimated return
        price = memeContract.getPrice(amount);
        uint256 refundAmount = (price * (100 - memeContract.BURN_TAX())) / 100;

        uint256 initialBalance = user.balance;

        memeContract.burn(amount);
        assertEq(memeContract.balanceOf(user), 0);
        assertEq(user.balance, initialBalance + refundAmount);
        vm.stopPrank();
    }

    function testMintWithETH() public {
        vm.startPrank(user);
        uint256 ethAmount = 1 ether;
        vm.deal(user, ethAmount);
        uint256 amount = memeContract.calculateTokensForETH(ethAmount);
        uint256 price = memeContract.getPrice(amount);
        if (ethAmount < price) {
            vm.expectRevert(BearsLoveMemes.InsufficientPayment.selector);
        } else {
            memeContract.mintWithETH{value: ethAmount}();
            assertEq(memeContract.balanceOf(user), amount);
        }
        vm.stopPrank();
    }

    function testMintWithETHHigher() public {
        vm.startPrank(user);
        uint256 ethAmount = 1000 ether;
        vm.deal(user, ethAmount);
        uint256 amount = memeContract.calculateTokensForETH(ethAmount);
        uint256 price = memeContract.getPrice(amount);
        if (ethAmount < price) {
            vm.expectRevert(BearsLoveMemes.InsufficientPayment.selector);
        } else {
            memeContract.mintWithETH{value: ethAmount}();
            assertEq(memeContract.balanceOf(user), amount);
        }
        vm.stopPrank();
    }

    function testHighAmountMinting() public {
        vm.startPrank(user);
        uint256 amount = 1000;
        uint256 price = memeContract.getPrice(amount);
        vm.deal(user, 100 ether);
        memeContract.mint{value: price}(amount);
        assertEq(memeContract.balanceOf(user), amount);
        vm.stopPrank();
    }
}
