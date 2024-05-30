// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {FixedPointMathLib} from "lib/solmate/src/utils/FixedPointMathLib.sol";
import {console} from "forge-std/console.sol";

contract BearsLoveMemes is ERC20, Ownable {
    using FixedPointMathLib for uint256;

    uint256 public constant BASE_PRICE = 0.000042 ether;
    uint256 public constant MIN_PRICE = 1000000 wei;
    uint256 public constant DELTA = 1.005e18;
    uint256 public constant BURN_TAX = 3; // 3% burn tax

    uint256 public circulatingSupply;

    error InsufficientPayment();

    event BearsLoveMemes_TokensMinted(
        address indexed account,
        uint256 amount,
        uint256 price
    );
    event BearsLoveMemes_TokensBurned(
        address indexed account,
        uint256 amount,
        uint256 refundAmount
    );

    constructor(
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) Ownable(msg.sender) {}

    function mint(uint256 amount) public payable {
        uint256 price = getPrice(amount);
        if (msg.value < price) {
            revert InsufficientPayment();
        }

        circulatingSupply += amount;
        _mint(msg.sender, amount);

        emit BearsLoveMemes_TokensMinted(msg.sender, amount, price);
    }

    function mintWithETH() public payable {
        uint256 ethAmount = msg.value;

        uint256 amount = calculateTokensForETH(ethAmount);
        uint256 price = getPrice(amount);

        if (ethAmount < price) {
            revert InsufficientPayment();
        }

        circulatingSupply += amount;
        _mint(msg.sender, amount);

        emit BearsLoveMemes_TokensMinted(msg.sender, amount, price);
    }

    function calculateTokensForETH(
        uint256 ethAmount
    ) public view returns (uint256) {
        uint256 currentSupply = circulatingSupply;
        uint256 totalPrice = 0;
        uint256 amount = 0;

        while (totalPrice < ethAmount) {
            uint256 currentPrice = BASE_PRICE.mulWadUp(
                DELTA.rpow(currentSupply + amount, FixedPointMathLib.WAD)
            );

            if (currentSupply + amount == 0) {
                currentPrice = BASE_PRICE;
            } else if (currentPrice < MIN_PRICE) {
                currentPrice = MIN_PRICE;
            }

            if (totalPrice + currentPrice > ethAmount) {
                break;
            }

            totalPrice += currentPrice;
            amount += 1;
        }

        return amount;
    }

    function getPrice(uint256 amount) public view returns (uint256) {
        uint256 currentSupply = circulatingSupply;

        if (amount == 0) return 0;

        uint256 startPrice = BASE_PRICE.mulWadUp(
            DELTA.rpow(currentSupply, FixedPointMathLib.WAD)
        );

        uint256 endPrice = BASE_PRICE.mulWadUp(
            DELTA.rpow(currentSupply + amount, FixedPointMathLib.WAD)
        );

        uint256 totalPrice = (endPrice - startPrice).divWadDown(
            DELTA - FixedPointMathLib.WAD
        );

        return totalPrice;
    }

    function burn(uint256 amount) public {
        uint256 price = getPrice(amount);
        uint256 refundAmount = (price * (100 - BURN_TAX)) / 100; // 97% refund

        circulatingSupply -= amount;
        _burn(msg.sender, amount);

        payable(msg.sender).transfer(refundAmount);
        emit BearsLoveMemes_TokensBurned(msg.sender, amount, refundAmount);
    }

    // For testing purposes so ETH doesn't get stuck
    function withdraw() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
