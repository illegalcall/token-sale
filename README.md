# Token Sale with Bancor Bonding Curve

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

| Action | USDC Amount | Tokens Received/Sold | Price Per Token |
|--------|-------------|----------------------|-----------------|
| 1st Buy | 10 USDC | ~20 tokens | ~0.50 USDC |
| 2nd Buy | 10 USDC | ~15 tokens | ~0.67 USDC |
| 3rd Buy | 10 USDC | ~12 tokens | ~0.83 USDC |
| Sell | 10 tokens | ~7 USDC | ~0.70 USDC |
| Buy After Sell | 10 USDC | ~14 tokens | ~0.71 USDC |

This demonstrates how the price increases with each purchase and decreases when tokens are sold.

## Development Setup

This project uses Foundry for Ethereum development.

### Prerequisites
1. Install Foundry:
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

2. Install dependencies:
```bash
forge install
```

3. Set up environment variables:
```bash
cp .env.example .env
# Edit .env with your values
```

### Build and Test

```bash
# Compile contracts
forge build

# Run tests
forge test

# View gas reports
forge snapshot
```

## Deployment Instructions

1. Set the PRIVATE_KEY environment variable:
```bash
export PRIVATE_KEY=0x<your-private-key>
```

2. Deploy to testnet:
```bash
forge script script/Deploy.s.sol:DeployScript --rpc-url <your-rpc-url> --broadcast --verify -vvvv
```

This will:
- Deploy the MockUSDC token
- Deploy the LaunchpadToken contract
- Deploy the BondingCurveSale contract
- Set up proper roles and permissions
- Verify contracts on Etherscan

## Contract Interaction Guide

### 1. Get Test USDC

```bash
cast send <USDC_ADDRESS> "mint(address,uint256)" <YOUR_ADDRESS> 1000000000 --rpc-url <your-rpc-url> --private-key <your-private-key>
```

### 2. Approve USDC Spending

```bash
cast send <USDC_ADDRESS> "approve(address,uint256)" <SALE_ADDRESS> 100000000 --rpc-url <your-rpc-url> --private-key <your-private-key>
```

### 3. Buy Tokens

```bash
cast send <SALE_ADDRESS> "buyTokens(uint256)" 10000000 --rpc-url <your-rpc-url> --private-key <your-private-key>
```

### 4. Check Token Balance

```bash
cast call <TOKEN_ADDRESS> "balanceOf(address)(uint256)" <YOUR_ADDRESS> --rpc-url <your-rpc-url>
```

### 5. Sell Tokens

First approve token spending:
```bash
cast send <TOKEN_ADDRESS> "approve(address,uint256)" <SALE_ADDRESS> 10000000000000000000 --rpc-url <your-rpc-url> --private-key <your-private-key>
```

Then sell:
```bash
cast send <SALE_ADDRESS> "sellTokens(uint256)" 10000000000000000000 --rpc-url <your-rpc-url> --private-key <your-private-key>
```

## Key Technical Features

- Smart contract deployment with proxy pattern for upgradeability
- ERC20 token implementation with role-based access control
- Bancor bonding curve algorithm implementation
- Token sale and buyback mechanism
- Contract verification on Etherscan

## License

This project is licensed under the MIT License.

## Contact

For any questions or clarification, please reach out directly at d3v.dhruv@gmail.com
