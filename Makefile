# Define variables
NETWORK_URL=https://rpc.sepolia.org
CHAIN_ID=11155111

# Compile contracts
compile:
	forge build

# Deploy BearsLoveMemes
deploy-bl:
	source .env && forge create src/BearsLoveMemes.sol:BearsLoveMemes --rpc-url $(NETWORK_URL) --private-key $$PRIVATE_KEY --constructor-args "Bears Love Memes" "BMEME"

# Deploy BearsLoveDefi (requires BearsLoveMemes address)
deploy-bd:
	source .env && forge create src/BearsLoveDefi.sol:BearsLoveDefi --rpc-url $(NETWORK_URL) --private-key $$PRIVATE_KEY --constructor-args $$MEME_CONTRACT_ADDRESS "0x0000000000000000000000000000000000000000" "0.69 ether"

# Deploy BearsLoveMountains (requires BearsLoveDefi address)
deploy-bm:
	source .env && forge create src/BearsLoveMountains.sol:BearsLoveMountains --rpc-url $(NETWORK_URL) --private-key $$PRIVATE_KEY --constructor-args "Bears Love Mountains" "MNTN" "0.001 ether" $$DEFI_CONTRACT_ADDRESS

# Set the NFT contract in the DeFi contract
set-nft-contract:
	source .env && forge script script/SetNftContract.s.sol:SetNftContract --rpc-url $(NETWORK_URL) --broadcast --etherscan-api-key $$EXPLORER_API_KEY --chain-id $(CHAIN_ID)

# Verify BearsLoveMemes
verify-bl:
	source .env && forge verify-contract --chain-id $(CHAIN_ID) --constructor-args $(cast abi-encode "constructor(string,string)" "Bears Love Memes" "BMEME") --etherscan-api-key $$EXPLORER_API_KEY $$MEME_CONTRACT_ADDRESS src/BearsLoveMemes.sol:BearsLoveMemes

# Verify BearsLoveDefi
verify-bd:
	source .env && forge verify-contract --chain-id $(CHAIN_ID) --constructor-args $(cast abi-encode "constructor(address,address,uint256)" $$MEME_CONTRACT_ADDRESS "0x0000000000000000000000000000000000000000" "0.69 ether") --etherscan-api-key $$EXPLORER_API_KEY $$DEFI_CONTRACT_ADDRESS src/BearsLoveDefi.sol:BearsLoveDefi

# Verify BearsLoveMountains
verify-bm:
	source .env && forge verify-contract --chain-id $(CHAIN_ID) --constructor-args $(cast abi-encode "constructor(string,string,uint256,address)" "Bears Love Mountains" "MNTN" "0.001 ether" $$DEFI_CONTRACT_ADDRESS) --etherscan-api-key $$EXPLORER_API_KEY $$BM_CONTRACT_ADDRESS src/BearsLoveMountains.sol:BearsLoveMountains

# Clean up build artifacts
clean:
	rm -rf out
	rm -rf cache

# Default target
all: compile deploy-bl deploy-bd deploy-bm set-nft-contract verify-bl verify-bd verify-bm
