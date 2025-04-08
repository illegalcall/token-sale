// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/BondingCurveSale.sol";
import "../src/LaunchpadToken.sol";
import "../src/mocks/MockUSDC.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract SimpleMockFactory {
    function getPair(address, address) external pure returns (address) {
        return address(0);
    }
}

contract SimpleMockRouter {
    SimpleMockFactory public factory;
    
    constructor(address factoryAddress) {
        factory = SimpleMockFactory(factoryAddress);
    }
    
    function addLiquidity(
        address, address, uint256, uint256, uint256, uint256, address, uint256
    ) external pure returns (uint256, uint256, uint256) {
        return (0, 0, 0);
    }
}

contract BondingCurveSaleTest is Test {
    LaunchpadToken public token;
    BondingCurveSale public saleImplementation;
    BondingCurveSale public sale;
    MockUSDC public usdc;
    SimpleMockRouter public router;
    SimpleMockFactory public factory;
    
    address public admin;
    address public fundCreator;
    address public platform;
    address public buyer;
    
    function setUp() public {
        console.log("=== Test setup starting ===");
        
        // Create addresses with predictable values for debugging
        admin = makeAddr("admin");
        fundCreator = makeAddr("fundCreator");
        platform = makeAddr("platform");
        buyer = makeAddr("buyer");
        
        console.log("Admin address:", admin);
        console.log("Fund creator address:", fundCreator);
        console.log("Platform address:", platform);
        
        // Deploy mocks
        usdc = new MockUSDC();
        factory = new SimpleMockFactory();
        router = new SimpleMockRouter(address(factory));
        
        console.log("USDC deployed at:", address(usdc));
        console.log("Router deployed at:", address(router));
        
        // Deploy token through proxy
        LaunchpadToken tokenImplementation = new LaunchpadToken();
        bytes memory tokenData = abi.encodeWithSelector(
            LaunchpadToken.initialize.selector,
            "Launchpad Token", 
            "LPT", 
            admin, 
            address(0)
        );
        ERC1967Proxy tokenProxy = new ERC1967Proxy(address(tokenImplementation), tokenData);
        token = LaunchpadToken(address(tokenProxy));
        
        console.log("Token deployed at:", address(token));
        console.log("Admin has admin role:", token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin));
        
        // Deploy sale through proxy
        saleImplementation = new BondingCurveSale();
        bytes memory saleData = abi.encodeWithSelector(
            BondingCurveSale.initialize.selector,
            address(token),
            address(usdc),
            address(router),
            fundCreator,
            platform,
            200000 // 20% reserve ratio
        );
        ERC1967Proxy saleProxy = new ERC1967Proxy(address(saleImplementation), saleData);
        sale = BondingCurveSale(address(saleProxy));
        
        console.log("Sale deployed at:", address(sale));
        
        // Grant minter role to sale
        vm.startPrank(admin);
        bytes32 minterRole = token.MINTER_ROLE();
        console.log("About to grant minter role. Role ID:", vm.toString(minterRole));
        console.log("Minter role exists:", token.getRoleAdmin(minterRole) != bytes32(0));
        token.grantRole(minterRole, address(sale));
        vm.stopPrank();
        
        console.log("Sale has minter role:", token.hasRole(minterRole, address(sale)));
        console.log("=== Test setup complete ===");
    }
    
    function testBasics() public {
        console.log("Basic test running");
        assertEq(uint256(1), uint256(1));
    }
    
    function testBuyTokens() public {
        console.log("=== Testing token purchase ===");
        
        // Mint some USDC to the buyer
        uint256 buyerUsdcAmount = 1000 * 10**6; // 1000 USDC with 6 decimals
        usdc.mint(buyer, buyerUsdcAmount);
        
        // Verify buyer has USDC
        assertEq(usdc.balanceOf(buyer), buyerUsdcAmount, "Buyer should have USDC");
        
        // Buyer approves the sale contract to spend USDC
        vm.startPrank(buyer);
        usdc.approve(address(sale), buyerUsdcAmount);
        
        // Check the initial price
        uint256 initialPrice = sale.getCurrentPrice();
        console.log("Initial token price (in USDC * 10^6):", initialPrice);
        
        // Calculate expected token amount
        uint256 usdcToSpend = 100 * 10**6; // 100 USDC
        uint256 expectedTokenAmount = sale.calculateTokenAmount(usdcToSpend);
        console.log("Expected token amount for 100 USDC:", expectedTokenAmount);
        
        // Buy tokens
        sale.buyTokens(usdcToSpend);
        vm.stopPrank();
        
        // Verify token balance
        uint256 buyerTokenBalance = token.balanceOf(buyer);
        console.log("Buyer token balance after purchase:", buyerTokenBalance);
        assertEq(buyerTokenBalance, expectedTokenAmount, "Buyer should receive correct token amount");
        
        // Verify USDC was transferred
        assertEq(usdc.balanceOf(buyer), buyerUsdcAmount - usdcToSpend, "Buyer USDC should be deducted");
        assertEq(usdc.balanceOf(address(sale)), usdcToSpend, "Sale contract should receive USDC");
        
        // Verify sale state was updated
        assertEq(sale.tokensSold(), expectedTokenAmount, "tokensSold should be updated");
        assertEq(sale.usdcRaised(), usdcToSpend, "usdcRaised should be updated");
        
        // Debug logs for price calculation
        console.log("Debug - tokensSold:", sale.tokensSold());
        console.log("Debug - usdcRaised:", sale.usdcRaised());
        console.log("Debug - reserveRatio:", sale.reserveRatio());
        console.log("Debug - SCALE constant should be 1000000");
        
        // Expected price calculation
        uint256 expectedNewPrice = (sale.usdcRaised() * 1000000 * 1000000) / (sale.tokensSold() * sale.reserveRatio());
        console.log("Debug - Expected new price calculation:", expectedNewPrice);
        
        // Check that price has increased
        uint256 newPrice = sale.getCurrentPrice();
        console.log("New price after purchase (in USDC * 10^6):", newPrice);
        assertTrue(newPrice > initialPrice, "Price should increase after purchase");
        
        console.log("=== Token purchase test complete ===");
    }
    
    function testFinalizeSale() public {
        console.log("=== Testing sale finalization ===");
        
        // Mint some USDC to the buyer
        uint256 buyerUsdcAmount = 1000 * 10**6; // 1000 USDC with 6 decimals
        usdc.mint(buyer, buyerUsdcAmount);
        
        // Buyer approves and buys tokens
        vm.startPrank(buyer);
        usdc.approve(address(sale), buyerUsdcAmount);
        uint256 usdcToSpend = 100 * 10**6; // 100 USDC
        sale.buyTokens(usdcToSpend);
        vm.stopPrank();
        
        // Verify initial state before finalization
        assertEq(token.balanceOf(buyer), 1000000000000000000000, "Buyer should have tokens");
        assertEq(token.balanceOf(fundCreator), 0, "Fund creator should have no tokens yet");
        assertEq(token.balanceOf(platform), 0, "Platform should have no tokens yet");
        assertEq(token.balanceOf(address(sale)), 0, "Sale contract should have no tokens yet");
        
        // Finalize sale as fund creator (owner)
        vm.prank(fundCreator);
        sale.finalizeSale();
        
        // Check that sale is finalized
        assertTrue(sale.isFinalized(), "Sale should be finalized");
        
        // Verify token distribution
        uint256 creatorAllocation = 200_000_000 * 10**18; // 200M tokens
        uint256 platformAllocation = 50_000_000 * 10**18; // 50M tokens
        uint256 liquidityAllocation = 250_000_000 * 10**18; // 250M tokens
        
        console.log("Fund creator token balance:", token.balanceOf(fundCreator));
        console.log("Platform token balance:", token.balanceOf(platform));
        
        // Since our mock router returns (0,0,0), all liquidity tokens are transferred back to fund creator
        // So fund creator receives creatorAllocation + liquidityAllocation
        uint256 expectedCreatorBalance = creatorAllocation + liquidityAllocation;
        
        assertEq(token.balanceOf(fundCreator), expectedCreatorBalance, "Fund creator should receive allocation + unused liquidity");
        assertEq(token.balanceOf(platform), platformAllocation, "Platform should receive correct allocation");
        
        // Check USDC distribution - all USDC is transferred to fund creator since mock router uses none
        uint256 expectedCreatorUSDC = usdcToSpend; // 100% of raised USDC due to mock
        assertEq(usdc.balanceOf(fundCreator), expectedCreatorUSDC, "Fund creator should receive all USDC");
        
        console.log("=== Sale finalization test complete ===");
    }
} 