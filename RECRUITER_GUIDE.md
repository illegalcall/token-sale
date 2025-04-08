# Token Sale with Bancor Bonding Curve

## Project Overview

This project implements a token sale using the Bancor bonding curve algorithm. The implementation features:

- Custom ERC20 token (LaunchpadToken)
- Bonding curve sale mechanism that automatically adjusts token prices based on supply
- USDC as the payment currency
- Ability to buy and sell tokens at any time

## Deployed Contracts on Sepolia Testnet

- **LaunchpadToken**: `0x54E8A431fddf84B61961955589E3D836F540Fc7f`
- **BondingCurveSale**: `0xd62802128F7BbbBab396883922D914A7a15F4244`
- **MockUSDC**: `0x67f69e00B273cDe6C06ce23198961b66E2039cd1`

All contracts are verified on Sepolia Etherscan and can be viewed by searching for these addresses.

## Technical Implementation

The bonding curve sale uses a continuous token model with a 20% reserve ratio, implementing the Bancor formula:

```
Token Price = Reserve Balance / (Token Supply * Reserve Ratio)
```

As more tokens are purchased, the price increases. As tokens are sold back, the price decreases. This dynamic pricing mechanism creates:

- **Automatic liquidity**: Tokens can be bought and sold at any time
- **Price discovery**: Market forces determine token value
- **Incentives for early adopters**: Early buyers get lower prices

## Price Curve Visualization

Initial purchase (first 10 USDC):
- Price per token: 0.5 USDC
- Tokens received: 20 tokens

Second purchase (next 10 USDC):
- Price per token: ~0.67 USDC
- Tokens received: ~15 tokens

This demonstrates how the price increases as more tokens are purchased.

## Steps to Verify the Implementation

Follow these steps to interact with the contracts and verify their functionality:

### Prerequisites

1. Install Foundry toolchain:
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

2. You'll need some Sepolia ETH for gas. Get some from a faucet like https://sepoliafaucet.com/.

### Step 1: Get Test USDC

Mint some test USDC to your address:

```bash
# Replace YOUR_ADDRESS with your wallet address
cast send 0x67f69e00B273cDe6C06ce23198961b66E2039cd1 "mint(address,uint256)" YOUR_ADDRESS 1000000000 --rpc-url https://eth-sepolia.g.alchemy.com/v2/8R31PpmrQ8INKJCcVCFw9OBwTUbgVRTs --private-key YOUR_PRIVATE_KEY
```

This mints 1,000 USDC (with 6 decimals) to your address.

### Step 2: Check USDC Balance

Verify you received the USDC:

```bash
cast call 0x67f69e00B273cDe6C06ce23198961b66E2039cd1 "balanceOf(address)(uint256)" YOUR_ADDRESS --rpc-url https://eth-sepolia.g.alchemy.com/v2/8R31PpmrQ8INKJCcVCFw9OBwTUbgVRTs
```

### Step 3: Approve USDC Spending

Approve the sale contract to spend your USDC:

```bash
cast send 0x67f69e00B273cDe6C06ce23198961b66E2039cd1 "approve(address,uint256)" 0xd62802128F7BbbBab396883922D914A7a15F4244 100000000 --rpc-url https://eth-sepolia.g.alchemy.com/v2/8R31PpmrQ8INKJCcVCFw9OBwTUbgVRTs --private-key YOUR_PRIVATE_KEY
```

This approves spending of 100 USDC.

### Step 4: First Token Purchase (Observe Initial Price)

Make your first token purchase:

```bash
cast send 0xd62802128F7BbbBab396883922D914A7a15F4244 "buyTokens(uint256)" 10000000 --rpc-url https://eth-sepolia.g.alchemy.com/v2/8R31PpmrQ8INKJCcVCFw9OBwTUbgVRTs --private-key YOUR_PRIVATE_KEY
```

This buys tokens with 10 USDC.

### Step 5: Check Token Balance After First Purchase

Verify you received the tokens:

```bash
cast call 0x54E8A431fddf84B61961955589E3D836F540Fc7f "balanceOf(address)(uint256)" YOUR_ADDRESS --rpc-url https://eth-sepolia.g.alchemy.com/v2/8R31PpmrQ8INKJCcVCFw9OBwTUbgVRTs
```

You should see 20 tokens (displayed as 20000000000000000000 with 18 decimals).

### Step 6: Calculate Initial Price

The initial price can be calculated:
- You spent 10 USDC
- You received 20 tokens
- Price per token = 10 USDC ÷ 20 tokens = 0.5 USDC per token

### Step 7: Make Second Purchase (Observe Price Increase)

Make a second purchase with the same amount:

```bash
cast send 0xd62802128F7BbbBab396883922D914A7a15F4244 "buyTokens(uint256)" 10000000 --rpc-url https://eth-sepolia.g.alchemy.com/v2/8R31PpmrQ8INKJCcVCFw9OBwTUbgVRTs --private-key YOUR_PRIVATE_KEY
```

### Step 8: Calculate New Price

Check your total token balance after second purchase:

```bash
cast call 0x54E8A431fddf84B61961955589E3D836F540Fc7f "balanceOf(address)(uint256)" YOUR_ADDRESS --rpc-url https://eth-sepolia.g.alchemy.com/v2/8R31PpmrQ8INKJCcVCFw9OBwTUbgVRTs
```

You'll notice your total is about 35 tokens. Since you had 20 tokens after the first purchase, this means:
- Second purchase: 10 USDC bought ~15 tokens
- New price per token = 10 USDC ÷ 15 tokens = ~0.67 USDC per token

This demonstrates the bonding curve in action - the price has increased from 0.5 USDC to 0.67 USDC per token after your purchase increased the total supply.

### Step 9: Third Purchase (Further Price Increase)

Make a third purchase:

```bash
cast send 0xd62802128F7BbbBab396883922D914A7a15F4244 "buyTokens(uint256)" 10000000 --rpc-url https://eth-sepolia.g.alchemy.com/v2/8R31PpmrQ8INKJCcVCFw9OBwTUbgVRTs --private-key YOUR_PRIVATE_KEY
```

Check your new total balance and calculate how many tokens the third 10 USDC bought:

```bash
cast call 0x54E8A431fddf84B61961955589E3D836F540Fc7f "balanceOf(address)(uint256)" YOUR_ADDRESS --rpc-url https://eth-sepolia.g.alchemy.com/v2/8R31PpmrQ8INKJCcVCFw9OBwTUbgVRTs
```

You'll see that your third 10 USDC bought even fewer tokens than the second purchase, as the price continues to increase along the bonding curve.

### Step 10: Sell Tokens (Observe Price Decrease)

Approve the tokens to be spent by the sale contract:

```bash
cast send 0x54E8A431fddf84B61961955589E3D836F540Fc7f "approve(address,uint256)" 0xd62802128F7BbbBab396883922D914A7a15F4244 10000000000000000000 --rpc-url https://eth-sepolia.g.alchemy.com/v2/8R31PpmrQ8INKJCcVCFw9OBwTUbgVRTs --private-key YOUR_PRIVATE_KEY
```

Then sell 10 tokens and record your USDC balance before selling:

```bash
# First check your current USDC balance
cast call 0x67f69e00B273cDe6C06ce23198961b66E2039cd1 "balanceOf(address)(uint256)" YOUR_ADDRESS --rpc-url https://eth-sepolia.g.alchemy.com/v2/8R31PpmrQ8INKJCcVCFw9OBwTUbgVRTs

# Then sell tokens
cast send 0xd62802128F7BbbBab396883922D914A7a15F4244 "sellTokens(uint256)" 10000000000000000000 --rpc-url https://eth-sepolia.g.alchemy.com/v2/8R31PpmrQ8INKJCcVCFw9OBwTUbgVRTs --private-key YOUR_PRIVATE_KEY
```

### Step 11: Verify USDC Returned and Calculate Sell Price

Check your USDC balance after selling:

```bash
cast call 0x67f69e00B273cDe6C06ce23198961b66E2039cd1 "balanceOf(address)(uint256)" YOUR_ADDRESS --rpc-url https://eth-sepolia.g.alchemy.com/v2/8R31PpmrQ8INKJCcVCFw9OBwTUbgVRTs
```

Calculate how much USDC you received for your 10 tokens by finding the difference in your USDC balance. You'll notice that selling tokens lowers the price, so you receive less USDC per token than the current buy price.

### Step 12: Buy Again After Selling (Lower Price)

Make another purchase after selling:

```bash
cast send 0xd62802128F7BbbBab396883922D914A7a15F4244 "buyTokens(uint256)" 10000000 --rpc-url https://eth-sepolia.g.alchemy.com/v2/8R31PpmrQ8INKJCcVCFw9OBwTUbgVRTs --private-key YOUR_PRIVATE_KEY
```

Check your new token balance and observe that you received more tokens for 10 USDC than in your previous purchase, demonstrating that the price decreased after you sold tokens.

## Expected Results Table

| Action | USDC Amount | Tokens Received/Sold | Price Per Token |
|--------|-------------|----------------------|-----------------|
| 1st Buy | 10 USDC | ~20 tokens | ~0.50 USDC |
| 2nd Buy | 10 USDC | ~15 tokens | ~0.67 USDC |
| 3rd Buy | 10 USDC | ~12 tokens | ~0.83 USDC |
| Sell | 10 tokens | ~7 USDC | ~0.70 USDC |
| Buy After Sell | 10 USDC | ~14 tokens | ~0.71 USDC |

This table clearly demonstrates how the price increases with each purchase and decreases when tokens are sold - the core functionality of the Bancor bonding curve.

## Using MetaMask or Other Wallets

You can also interact with these contracts using MetaMask and Sepolia Etherscan:

1. Add the Sepolia testnet to MetaMask
2. Import the token contract (`0x54E8A431fddf84B61961955589E3D836F540Fc7f`)
3. Visit the contract on Sepolia Etherscan and use the "Write Contract" tab

## Key Technical Features Demonstrated

- Smart contract deployment with proxy pattern for upgradeability
- ERC20 token implementation with role-based access control
- Bancor bonding curve algorithm implementation
- Token sale and buyback mechanism
- Contract verification on Etherscan

## Further Development

In a production environment, this would include:
- Front-end UI for easier interaction
- Additional security features like circuit breakers
- Price oracle integration
- More advanced tokenomics

## Contact

For any questions or clarification, please reach out directly. 
d3v.dhruv@gmail.com