// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {BearsLoveMemes} from "./BearsLoveMemes.sol";
import {console} from "forge-std/console.sol";
import {BearsLoveMountains} from "./BearsLoveMountains.sol";

contract BearsLoveDefi is Ownable {
    BearsLoveMemes public memeToken;
    BearsLoveMountains public nftContract;
    uint256 public threshold;

    mapping(address => uint256) public nftHoldings;
    mapping(address => uint256) public memeClaims;
    uint256 public totalCirculation;
    address[] public holders;

    event BearsLoveDefi_TokensPurchased(uint256 ethAmount, uint256 memeAmount);
    event MemeCoinsDistributed(uint256 totalMemeAmount);

    constructor(
        address _memeToken,
        address _nftContract,
        uint256 _threshold
    ) Ownable(msg.sender) {
        memeToken = BearsLoveMemes(_memeToken);
        nftContract = BearsLoveMountains(_nftContract);
        threshold = _threshold;
    }

    function setNftContract(address _nftContract) external onlyOwner {
        nftContract = BearsLoveMountains(_nftContract);
    }

    receive() external payable {
        if (address(this).balance >= threshold) {
            buyMemeTokens();
        }
    }

    function buyMemeTokens() internal {
        uint256 ethAmount = address(this).balance;

        // Mint BearsLoveMemes tokens using the bonding curve
        memeToken.mintWithETH{value: ethAmount}();

        uint256 memeAmount = memeToken.balanceOf(address(this));

        distributeMemeCoins(memeAmount);

        // Emit an event with the purchased amount
        emit BearsLoveDefi_TokensPurchased(ethAmount, memeAmount);
    }

    function distributeMemeCoins(uint256 memeAmount) internal {
        for (uint256 i = 0; i < holders.length; i++) {
            address holder = holders[i];
            uint256 holderBalance = nftHoldings[holder];
            if (holderBalance > 0) {
                uint256 claimAmount = (memeAmount * holderBalance) /
                    totalCirculation;
                memeClaims[holder] += claimAmount;
            }
        }
        emit MemeCoinsDistributed(memeAmount);
    }

    function updateTotals(
        address account,
        uint256 amount,
        bool isMinting
    ) external {
        require(
            msg.sender == address(nftContract),
            "Only NFT contract can update totals"
        );

        if (isMinting) {
            // if they're not in the mapping, they're not in the array
            if (nftHoldings[account] == 0) {
                holders.push(account);
            }
            nftHoldings[account] += amount;
            totalCirculation += amount;
        } else {
            nftHoldings[account] -= amount;
            totalCirculation -= amount;
            if (nftHoldings[account] == 0) {
                // Remove the account from holders array
                for (uint256 i = 0; i < holders.length; i++) {
                    if (holders[i] == account) {
                        holders[i] = holders[holders.length - 1];
                        holders.pop();
                        break;
                    }
                }
            }
        }
    }

    function checkClaimableMeme(
        address account
    ) external view returns (uint256) {
        return memeClaims[account];
    }

    function claimMeme() external {
        uint256 claimAmount = memeClaims[msg.sender];
        require(claimAmount > 0, "Nothing to claim");

        memeClaims[msg.sender] = 0;
        memeToken.transfer(msg.sender, claimAmount);
    }

    function withdraw() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
