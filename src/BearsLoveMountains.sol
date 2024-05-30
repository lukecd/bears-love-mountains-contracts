// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {ERC1155Burnable} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {console} from "forge-std/console.sol";
import {FixedPointMathLib} from "lib/solmate/src/utils/FixedPointMathLib.sol";
import {BearsLoveDefi} from "../src/BearsLoveDefi.sol";

contract BearsLoveMountains is ERC1155, ERC1155Burnable, Ownable {
    using FixedPointMathLib for uint256;

    string public name;
    string public symbol;

    uint256 public constant MAX_TOKEN_ID = 8;
    uint256 public constant BASE_PRICE = 0.042 ether;
    uint256 public constant MIN_PRICE = 1000000 wei;
    uint256 public constant DELTA = 1.005e18;
    uint256 public constant BURN_TAX = 3; // 3% burn tax

    uint256 public salesTaxThreshold;
    uint256 public accumulatedTax;
    BearsLoveDefi public defiContract;

    mapping(uint256 => uint256) public circulatingSupply;

    error TokenIdExceedsMaximum();
    error InsufficientPayment();
    error InsufficientBalance();

    event BearsLoveMountains_TokensMinted(
        address indexed account,
        uint256 indexed tokenId,
        uint256 amount,
        uint256 price
    );
    event BearsLoveMountains_TokensBurned(
        address indexed account,
        uint256 indexed tokenId,
        uint256 amount,
        uint256 refundAmount,
        uint256 taxAmount
    );
    event BearsLoveMountains_TaxTransferred(uint256 amount);

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _salesTaxThreshold,
        address _defiContract
    )
        ERC1155(
            "https://gateway.irys.xyz/Kju4OAsYqyNeApRmr6-j7u9E_f1LEboi-jOskNlletE/{id}.json"
        )
        Ownable(msg.sender)
    {
        name = _name;
        symbol = _symbol;
        salesTaxThreshold = _salesTaxThreshold;
        defiContract = BearsLoveDefi(payable(_defiContract));
    }

    function uri(uint256 tokenId) public pure override returns (string memory) {
        if (tokenId > MAX_TOKEN_ID) {
            revert TokenIdExceedsMaximum();
        }
        return
            string(
                abi.encodePacked(
                    "https://gateway.irys.xyz/Kju4OAsYqyNeApRmr6-j7u9E_f1LEboi-jOskNlletE/",
                    Strings.toString(tokenId),
                    ".json"
                )
            );
    }

    function contractURI() public pure returns (string memory) {
        return
            "https://gateway.irys.xyz/Kju4OAsYqyNeApRmr6-j7u9E_f1LEboi-jOskNlletE/collection.json";
    }

    function mint(uint256 tokenId, uint256 amount) public payable {
        if (tokenId > MAX_TOKEN_ID) {
            revert TokenIdExceedsMaximum();
        }

        uint256 price = getPrice(tokenId, amount, true);
        if (msg.value < price) {
            revert InsufficientPayment();
        }

        circulatingSupply[tokenId] += amount;
        _mint(msg.sender, tokenId, amount, "");

        defiContract.updateTotals(msg.sender, amount, true);

        emit BearsLoveMountains_TokensMinted(
            msg.sender,
            tokenId,
            amount,
            price
        );
    }

    function burn(uint256 tokenId, uint256 amount) public {
        uint256 balance = balanceOf(msg.sender, tokenId);
        if (balance < amount) {
            revert InsufficientBalance();
        }

        uint256 price = getPrice(tokenId, amount, false);
        uint256 refundAmount = (price * (100 - BURN_TAX)) / 100; // 97% refund
        uint256 taxAmount = price - refundAmount; // 3% tax

        circulatingSupply[tokenId] -= amount;
        accumulatedTax += taxAmount;

        _burn(msg.sender, tokenId, amount);
        defiContract.updateTotals(msg.sender, amount, false);

        payable(msg.sender).transfer(refundAmount);

        emit BearsLoveMountains_TokensBurned(
            msg.sender,
            tokenId,
            amount,
            refundAmount,
            taxAmount
        );

        if (accumulatedTax >= salesTaxThreshold) {
            transferTaxToDefiContract();
        }
    }

    function getPrice(
        uint256 tokenId,
        uint256 amount,
        bool isMinting
    ) public view returns (uint256) {
        uint256 currentSupply = circulatingSupply[tokenId];
        uint256 totalPrice = 0;

        if (isMinting) {
            for (uint256 i = 0; i < amount; i++) {
                uint256 currentPrice = BASE_PRICE.mulWadUp(
                    DELTA.rpow(currentSupply + i, FixedPointMathLib.WAD)
                );
                if (currentSupply + i == 0) {
                    currentPrice = BASE_PRICE;
                } else if (currentPrice < MIN_PRICE) {
                    currentPrice = MIN_PRICE;
                }
                totalPrice += currentPrice;
            }
        } else {
            // Burning
            for (uint256 i = 0; i < amount; i++) {
                uint256 currentPrice = BASE_PRICE.mulWadUp(
                    DELTA.rpow(currentSupply - i - 1, FixedPointMathLib.WAD)
                );
                if (currentSupply - i - 1 == 0) {
                    currentPrice = BASE_PRICE;
                } else if (currentPrice < MIN_PRICE) {
                    currentPrice = MIN_PRICE;
                }
                totalPrice += currentPrice;
            }
        }

        return totalPrice;
    }

    function transferTaxToDefiContract() internal {
        uint256 taxAmount = accumulatedTax;
        accumulatedTax = 0;

        (bool success, ) = address(defiContract).call{value: taxAmount}("");
        require(success, "Transfer to defi contract failed");

        emit BearsLoveMountains_TaxTransferred(taxAmount);
    }

    function withdraw() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
