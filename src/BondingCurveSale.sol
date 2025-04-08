// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./LaunchpadToken.sol";

/**
 * @title BondingCurveSale
 * @dev A contract for selling tokens using a bonding curve.
 * The price of tokens increases as more tokens are sold.
 * 
 * Distribution plan:
 * - 500M tokens (50%) sold via bonding curve to public
 * - 200M tokens (20%) allocated to fund creator
 * - 250M tokens (25%) allocated to Uniswap liquidity pool
 * - 50M tokens (5%) allocated to platform as a fee
 */
contract BondingCurveSale is 
    Initializable, 
    OwnableUpgradeable, 
    ReentrancyGuardUpgradeable, 
    UUPSUpgradeable 
{
    // Events
    event TokensPurchased(address indexed buyer, uint256 usdcAmount, uint256 tokensReceived, uint256 currentPrice);
    event SaleFinalized(uint256 totalTokensSold, uint256 totalUsdcRaised);
    event LiquidityAdded(address indexed pair, uint256 tokensAdded, uint256 usdcAdded);

    // Tokens to be sold via bonding curve
    uint256 public constant SALE_ALLOCATION = 500_000_000 * 10**18;  // 500M tokens with 18 decimals
    
    // Team allocation
    uint256 public constant CREATOR_ALLOCATION = 200_000_000 * 10**18;  // 200M tokens
    
    // Liquidity pool allocation
    uint256 public constant LIQUIDITY_ALLOCATION = 250_000_000 * 10**18;  // 250M tokens
    
    // Platform fee allocation
    uint256 public constant PLATFORM_FEE_ALLOCATION = 50_000_000 * 10**18;  // 50M tokens

    // Token contract
    LaunchpadToken public token;
    
    // USDC contract
    IERC20 public usdc;
    
    // Uniswap router for adding liquidity
    IUniswapV2Router02 public uniswapRouter;
    
    // Fund creator address who will receive funds
    address public fundCreator;
    
    // Platform address to receive the platform fee
    address public platform;
    
    // Bonding curve parameters
    uint256 public reserveRatio;  // Ratio of reserve to token market cap (in parts per million)
    
    // Sale state
    uint256 public tokensSold;
    uint256 public usdcRaised;
    
    // Flag to indicate if the sale is finalized
    bool public isFinalized;

    // Constant for scaling calculations (used for fixed-point math)
    uint32 private constant SCALE = 1000000;  // 10^6 for calculations with 6 decimal precision

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializes the sale contract
     * @param _token The address of the token to be sold
     * @param _usdc The address of the USDC token
     * @param _router The address of the Uniswap router
     * @param _fundCreator The address of the fund creator
     * @param _platform The address of the platform
     * @param _reserveRatio The reserve ratio for the bonding curve in parts per million (e.g., 200000 for 20%)
     */
    function initialize(
        address _token,
        address _usdc,
        address _router,
        address _fundCreator,
        address _platform,
        uint256 _reserveRatio
    ) public initializer {
        __Ownable_init(_fundCreator);  // Fund creator is the owner of the sale contract
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        
        require(_token != address(0), "Token address cannot be zero");
        require(_usdc != address(0), "USDC address cannot be zero");
        require(_router != address(0), "Router address cannot be zero");
        require(_fundCreator != address(0), "Fund creator address cannot be zero");
        require(_platform != address(0), "Platform address cannot be zero");
        require(_reserveRatio > 0 && _reserveRatio <= SCALE, "Invalid reserve ratio");
        
        token = LaunchpadToken(_token);
        usdc = IERC20(_usdc);
        uniswapRouter = IUniswapV2Router02(_router);
        fundCreator = _fundCreator;
        platform = _platform;
        reserveRatio = _reserveRatio;
        
        tokensSold = 0;
        usdcRaised = 0;
        isFinalized = false;
    }

    /**
     * @dev Calculates the current token price based on the bonding curve formula
     * @return The current price of 1 token in USDC (with 6 decimals as USDC)
     */
    function getCurrentPrice() public view returns (uint256) {
        if (tokensSold == 0) {
            // Initial price when no tokens are sold
            return 100000;  // $0.10 with 6 decimals
        }
        
        // Bancor formula adjusted for token decimals difference:
        // For token with 18 decimals and USDC with 6 decimals, we need to adjust by 10^12
        // price = (usdcRaised * SCALE * SCALE) / (tokensSold / 10^12 * reserveRatio)
        
        // First convert tokensSold to a smaller scale (divide by 10^12) to avoid overflow
        // and account for decimal difference between tokens and USDC
        uint256 adjustedTokensSold = tokensSold / 10**12;
        
        // Prevent division by zero
        if (adjustedTokensSold == 0) {
            return 100000;  // Default to initial price
        }
        
        return (usdcRaised * SCALE * SCALE) / (adjustedTokensSold * reserveRatio);
    }

    /**
     * @dev Calculates how many tokens will be received for a given USDC amount
     * @param usdcAmount The amount of USDC to spend (with 6 decimals)
     * @return tokensToReceive The number of tokens the buyer will receive (with 18 decimals)
     * 
     * Note: This calculation is an approximation. For large purchases, consider breaking them
     * into smaller chunks for more accurate pricing.
     */
    function calculateTokenAmount(uint256 usdcAmount) public view returns (uint256) {
        if (tokensSold == SALE_ALLOCATION) {
            return 0;  // All tokens sold
        }
        
        if (tokensSold == 0) {
            // First buyer gets tokens at the initial price
            return (usdcAmount * 10**18) / 100000;  // Convert from 6 decimals to 18 decimals and divide by initial price
        }
        
        // Use the current formula based on reserve ratio
        // Formula: tokens = totalSupply * ((1 + usdcAmount / reserve)^reserveRatio - 1)
        
        // For simplicity, we use a linear approximation:
        // tokens = usdcAmount / currentPrice
        uint256 currentPrice = getCurrentPrice();
        uint256 tokensToReceive = (usdcAmount * 10**18) / currentPrice;
        
        // Ensure we don't exceed the sale allocation
        uint256 remainingTokens = SALE_ALLOCATION - tokensSold;
        if (tokensToReceive > remainingTokens) {
            tokensToReceive = remainingTokens;
        }
        
        return tokensToReceive;
    }

    /**
     * @dev Allows a user to buy tokens by sending USDC
     * @param usdcAmount The amount of USDC to spend (with 6 decimals)
     */
    function buyTokens(uint256 usdcAmount) external nonReentrant {
        require(!isFinalized, "Sale is already finalized");
        require(usdcAmount > 0, "USDC amount must be greater than 0");
        require(tokensSold < SALE_ALLOCATION, "All tokens have been sold");
        
        // Calculate tokens to receive
        uint256 tokensToReceive = calculateTokenAmount(usdcAmount);
        require(tokensToReceive > 0, "Token amount too small");
        
        // Adjust USDC amount if not enough tokens are left
        uint256 remainingTokens = SALE_ALLOCATION - tokensSold;
        if (tokensToReceive > remainingTokens) {
            tokensToReceive = remainingTokens;
            
            // Recalculate USDC amount based on current price and adjusted token amount
            uint256 currentPrice = getCurrentPrice();
            usdcAmount = (tokensToReceive * currentPrice) / 10**18;
        }
        
        // Transfer USDC from the buyer to this contract
        require(usdc.transferFrom(msg.sender, address(this), usdcAmount), "USDC transfer failed");
        
        // Mint tokens to the buyer
        token.mint(msg.sender, tokensToReceive);
        
        // Update sale state
        tokensSold += tokensToReceive;
        usdcRaised += usdcAmount;
        
        // Emit event
        emit TokensPurchased(msg.sender, usdcAmount, tokensToReceive, getCurrentPrice());
        
        // Check if all tokens have been sold
        if (tokensSold == SALE_ALLOCATION) {
            finalizeSale();
        }
    }

    /**
     * @dev Finalizes the sale, distributes tokens and USDC
     * Can only be called by the owner or automatically when all tokens are sold
     */
    function finalizeSale() public nonReentrant {
        require(!isFinalized, "Sale is already finalized");
        require(msg.sender == owner() || tokensSold == SALE_ALLOCATION, "Not authorized");
        
        isFinalized = true;
        
        // 1. Mint creator tokens (20%)
        token.mint(fundCreator, CREATOR_ALLOCATION);
        
        // 2. Mint platform fee tokens (5%)
        token.mint(platform, PLATFORM_FEE_ALLOCATION);
        
        // 3. Mint tokens for liquidity (25%)
        token.mint(address(this), LIQUIDITY_ALLOCATION);
        
        // 4. Calculate USDC amounts to distribute
        uint256 usdcForCreator = usdcRaised / 2;  // 50% of raised USDC
        uint256 usdcForLiquidity = usdcRaised - usdcForCreator;  // 50% of raised USDC
        
        // 5. Transfer 50% of USDC to fund creator
        require(usdc.transfer(fundCreator, usdcForCreator), "USDC transfer to creator failed");
        
        // 6. Add liquidity to Uniswap with 25% of tokens and 50% of USDC
        addLiquidityToUniswap(LIQUIDITY_ALLOCATION, usdcForLiquidity);
        
        // Emit event
        emit SaleFinalized(tokensSold, usdcRaised);
    }

    /**
     * @dev Adds liquidity to Uniswap with the specified token and USDC amounts
     * @param tokenAmount The amount of tokens to add to the liquidity pool
     * @param usdcAmount The amount of USDC to add to the liquidity pool
     */
    function addLiquidityToUniswap(uint256 tokenAmount, uint256 usdcAmount) internal {
        // Approve router to spend tokens and USDC
        token.approve(address(uniswapRouter), tokenAmount);
        usdc.approve(address(uniswapRouter), usdcAmount);
        
        // Set a reasonable deadline for the transaction
        uint256 deadline = block.timestamp + 15 minutes;
        
        // Add liquidity
        (uint256 amountToken, uint256 amountUSDC, uint256 liquidity) = uniswapRouter.addLiquidity(
            address(token),
            address(usdc),
            tokenAmount,
            usdcAmount,
            0,  // Accept any amount of tokens (slippage)
            0,  // Accept any amount of USDC (slippage)
            fundCreator,  // LP tokens go to fund creator
            deadline
        );
        
        // Check if there are any unused tokens or USDC
        uint256 unusedTokens = tokenAmount - amountToken;
        uint256 unusedUSDC = usdcAmount - amountUSDC;
        
        // Transfer any unused tokens back to fund creator
        if (unusedTokens > 0) {
            require(token.transfer(fundCreator, unusedTokens), "Token transfer failed");
        }
        
        // Transfer any unused USDC back to fund creator
        if (unusedUSDC > 0) {
            require(usdc.transfer(fundCreator, unusedUSDC), "USDC transfer failed");
        }
        
        // Get the pair address
        address factory = uniswapRouter.factory();
        address pair = IUniswapV2Factory(factory).getPair(address(token), address(usdc));
        
        // Emit event
        emit LiquidityAdded(pair, amountToken, amountUSDC);
    }

    /**
     * @dev UUPS upgrade authorization
     * @param newImplementation The address of the new implementation
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
} 