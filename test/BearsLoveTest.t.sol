// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {BearsLoveMountains} from "../src/BearsLoveMountains.sol";
import {BearsLoveMemes} from "../src/BearsLoveMemes.sol";
import {BearsLoveDefi} from "../src/BearsLoveDefi.sol";
import {DeployAll} from "../script/DeployAll.s.sol";
import {console} from "forge-std/console.sol";

contract BearsLoveTest is Test {
    BearsLoveMountains blm;
    BearsLoveMemes memeToken;
    BearsLoveDefi defiContract;

    address owner = address(1);
    address user = address(2);

    function setUp() public {
        vm.startPrank(owner);
        DeployAll deployScript = new DeployAll();
        (blm, memeToken, defiContract) = deployScript.run();
        vm.stopPrank();
    }

    function testEcosystem() public {
        // Setup initial parameters
        vm.startPrank(user);
        uint256 tokenId = 1;
        uint256 amountToMint = 1;
        uint256 amountToBurn = 1;
        uint256 threshold = defiContract.threshold();
        uint256 burnTaxAccumulated = 0;
        uint256 totalMinted = 0;
        uint256 totalBurned = 0;

        vm.deal(user, 100 ether); // Provide sufficient funds

        // Check balance before minting / burning
        uint256 initialMemeBalance = memeToken.balanceOf(address(defiContract));

        // Mint one NFT that won't get burned, this way we have
        // a holder registerd when its time to distribute tokens
        blm.mint{value: blm.getPrice(tokenId, amountToMint, true)}(
            tokenId,
            amountToMint
        );

        // Mint NFTs dynamically until we can burn enough to exceed the threshold
        while (burnTaxAccumulated < threshold) {
            uint256 mintPrice = blm.getPrice(tokenId, amountToMint, true);
            blm.mint{value: mintPrice}(tokenId, amountToMint);
            totalMinted += amountToMint;

            uint256 burnPrice = blm.getPrice(tokenId, amountToBurn, false);
            uint256 refundAmount = (burnPrice * (100 - blm.BURN_TAX())) / 100;
            burnTaxAccumulated += burnPrice - refundAmount;

            blm.burn(tokenId, amountToBurn);
            totalBurned += amountToBurn;
        }
        // Validate that the meme tokens were purchased
        uint256 finalMemeBalance = memeToken.balanceOf(address(defiContract));
        assertGt(finalMemeBalance, initialMemeBalance);
        console.log("finalMemeBalance=", finalMemeBalance);

        // Check claimable meme tokens for the user
        uint256 claimable = defiContract.checkClaimableMeme(user);
        console.log("claimable=", claimable);

        assertGt(claimable, 0);

        // Claim meme tokens
        // defiContract.claimMeme();
        // uint256 claimedBalance = memeToken.balanceOf(user);
        // assertEq(claimable, claimedBalance);

        vm.stopPrank();
    }

    function testAndLogEcosystem() public {
        vm.startPrank(user);

        uint256 tokenId = 1;
        uint256 amountToMint = 1;
        uint256 amountToBurn = 1;

        vm.deal(user, 10000 ether);

        writeCSVLine(
            "NFT Circulating Supply,NFT Price,Meme Coin Circulating Supply,Meme Coin Price"
        );

        // Mint 1000 NFTs one by one
        for (uint256 i = 0; i < 1000; i++) {
            uint256 nftPrice = blm.getPrice(tokenId, amountToMint, true);
            blm.mint{value: nftPrice}(tokenId, amountToMint);
            logData(tokenId, amountToMint, true);
        }

        // Burn 500 NFTs one by one
        for (uint256 i = 0; i < 500; i++) {
            blm.burn(tokenId, amountToBurn);
            logData(tokenId, amountToBurn, false);
        }

        vm.stopPrank();
    }

    function logData(uint256 tokenId, uint256 amount, bool isMint) internal {
        uint256 nftCirculatingSupply = blm.circulatingSupply(tokenId);
        uint256 nftPrice = blm.getPrice(tokenId, amount, isMint);
        uint256 memeCirculatingSupply = memeToken.totalSupply();
        uint256 memePrice = memeToken.getPrice(amount);

        string memory data = string(
            abi.encodePacked(
                uintToStr(nftCirculatingSupply),
                ",",
                uintToStr(nftPrice),
                ",",
                uintToStr(memeCirculatingSupply),
                ",",
                uintToStr(memePrice)
            )
        );

        writeCSVLine(data);
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
