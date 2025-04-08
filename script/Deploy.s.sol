// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "../src/LaunchpadToken.sol";
import "../src/BondingCurveSale.sol";
import "../src/mocks/MockUSDC.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// Simple mock contracts for deployment
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

contract DeployScript is Script {
    // Contract addresses
    address public tokenAddress;
    address public saleAddress;
    address public usdcAddress;
    address public routerAddress;
    address public factoryAddress;
    address public deployer;
    
    function run() external {
        // Get private key from env
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.addr(deployerPrivateKey);
        console.log("Deployer address:", deployer);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy in steps to reduce stack variables
        deployMocks();
        deployToken();
        deploySale();
        setupRoles();
        
        vm.stopBroadcast();
        
        // Log addresses to console
        logAddresses();
    }
    
    function deployMocks() internal {
        // Deploy MockUSDC if needed (for testnet)
        MockUSDC usdc = new MockUSDC();
        usdcAddress = address(usdc);
        console.log("MockUSDC deployed at:", usdcAddress);
        
        // Deploy mock factory and router for Uniswap integration
        SimpleMockFactory factory = new SimpleMockFactory();
        factoryAddress = address(factory);
        console.log("MockFactory deployed at:", factoryAddress);
        
        SimpleMockRouter router = new SimpleMockRouter(factoryAddress);
        routerAddress = address(router);
        console.log("MockRouter deployed at:", routerAddress);
    }
    
    function deployToken() internal {
        // Deploy token implementation and proxy
        LaunchpadToken tokenImplementation = new LaunchpadToken();
        bytes memory tokenData = abi.encodeWithSelector(
            LaunchpadToken.initialize.selector,
            "Launchpad Token", 
            "LPT", 
            deployer, // Admin - use deployer address explicitly
            address(0)  // Initial minter (will be set to sale contract)
        );
        ERC1967Proxy tokenProxy = new ERC1967Proxy(address(tokenImplementation), tokenData);
        tokenAddress = address(tokenProxy);
        console.log("Token deployed at:", tokenAddress);
    }
    
    function deploySale() internal {
        // Deploy sale implementation and proxy
        BondingCurveSale saleImplementation = new BondingCurveSale();
        bytes memory saleData = abi.encodeWithSelector(
            BondingCurveSale.initialize.selector,
            tokenAddress,
            usdcAddress,
            routerAddress,
            deployer, // Fund creator - use deployer address explicitly
            deployer, // Platform address - use deployer address explicitly
            200000     // 20% reserve ratio
        );
        ERC1967Proxy saleProxy = new ERC1967Proxy(address(saleImplementation), saleData);
        saleAddress = address(saleProxy);
        console.log("Sale deployed at:", saleAddress);
    }
    
    function setupRoles() internal {
        // Grant minter role to sale contract
        LaunchpadToken token = LaunchpadToken(tokenAddress);
        bytes32 minterRole = token.MINTER_ROLE();
        console.log("Minter role:", vm.toString(minterRole));
        
        // Check if deployer has admin role
        bytes32 adminRole = token.DEFAULT_ADMIN_ROLE();
        console.log("Admin role:", vm.toString(adminRole));
        console.log("Deployer has admin role:", token.hasRole(adminRole, deployer));
        
        // Grant minter role to sale contract
        token.grantRole(minterRole, saleAddress);
        console.log("Minter role granted to sale contract");
    }
    
    function logAddresses() internal view {
        // Log addresses for easy copy-paste
        console.log("\n=== DEPLOYMENT ADDRESSES ===");
        console.log("DEPLOYER_ADDRESS:", deployer);
        console.log("TOKEN_ADDRESS:", tokenAddress);
        console.log("SALE_ADDRESS:", saleAddress);
        console.log("USDC_ADDRESS:", usdcAddress);
        console.log("ROUTER_ADDRESS:", routerAddress);
        console.log("FACTORY_ADDRESS:", factoryAddress);
        console.log("=== DEPLOYMENT COMPLETE ===\n");
    }
} 