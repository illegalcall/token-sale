# Deployment Instructions

## Prerequisites

1. **Install Foundry**:
   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

2. **Get Testnet ETH**:
   - You need Sepolia ETH to deploy the contracts
   - Visit the Sepolia faucet: https://sepoliafaucet.com/
   - Or use Alchemy faucet: https://www.alchemy.com/faucets/ethereum-sepolia
   - Request ETH for your deployment address

3. **Set up environment variables**:
   ```bash
   # Create a .env file with your deployment keys
   echo 'PRIVATE_KEY=your_private_key_here' > .env
   echo 'RPC_URL=https://eth-sepolia.g.alchemy.com/v2/your_api_key' >> .env
   echo 'ETHERSCAN_API_KEY=your_etherscan_api_key' >> .env
   ```

## Deployment Steps

1. **Source the environment variables**:
   ```bash
   source .env
   ```

2. **Run the deployment script**:
   ```bash
   forge script script/Deploy.s.sol:DeployScript \
     --rpc-url $RPC_URL \
     --private-key $PRIVATE_KEY \
     --broadcast \
     --verify \
     -vvvv
   ```

3. **Save the deployed contract addresses**:
   The script will output the addresses of all deployed contracts. Copy these from the console output or from the broadcast output file.

## Expected Output

When the deployment completes successfully, you'll see output like:

```
=== DEPLOYMENT ADDRESSES ===
DEPLOYER_ADDRESS: 0x...
TOKEN_ADDRESS: 0x...
SALE_ADDRESS: 0x...
USDC_ADDRESS: 0x...
ROUTER_ADDRESS: 0x...
FACTORY_ADDRESS: 0x...
=== DEPLOYMENT COMPLETE ===
```

## Verifying Contracts

The `--verify` flag in the deployment command should automatically verify the contracts on Etherscan. If not, you can manually verify using:

```bash
forge verify-contract --chain-id 11155111 \
  --constructor-args $(cast abi-encode "constructor()" ) \
  <DEPLOYED_CONTRACT_ADDRESS> \
  <CONTRACT_PATH>:<CONTRACT_NAME> \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

## Testing the Deployed Contracts

After deployment, you can interact with the contracts:

1. **Mint USDC**:
   ```bash
   cast send --rpc-url $RPC_URL \
     --private-key $PRIVATE_KEY \
     $USDC_ADDRESS "mint(address,uint256)" \
     $DEPLOYER_ADDRESS 1000000000000 # 1,000,000 USDC
   ```

2. **Approve USDC for Sale Contract**:
   ```bash
   cast send --rpc-url $RPC_URL \
     --private-key $PRIVATE_KEY \
     $USDC_ADDRESS "approve(address,uint256)" \
     $SALE_ADDRESS 1000000000000 # 1,000,000 USDC
   ```

3. **Buy Tokens**:
   ```bash
   cast send --rpc-url $RPC_URL \
     --private-key $PRIVATE_KEY \
     $SALE_ADDRESS "buyTokens(uint256)" 100000000 # 100 USDC
   ```

4. **Check Token Balance**:
   ```bash
   cast call --rpc-url $RPC_URL \
     $TOKEN_ADDRESS "balanceOf(address)" $DEPLOYER_ADDRESS
   ```

5. **Finalize Sale**:
   ```bash
   cast send --rpc-url $RPC_URL \
     --private-key $PRIVATE_KEY \
     $SALE_ADDRESS "finalizeSale()"
   ``` 