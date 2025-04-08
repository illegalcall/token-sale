// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../src/LaunchpadToken.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract LaunchpadTokenTest is Test {
    LaunchpadToken public implementation;
    LaunchpadToken public token;
    ERC1967Proxy public proxy;

    address public admin;
    address public minter;
    address public user;
    address public newMinter;

    string public constant NAME = "Launchpad Token";
    string public constant SYMBOL = "LPT";

    // Events for testing
    event RoleGranted(bytes32, address, address);
    event RoleRevoked(bytes32, address, address);

    function setUp() public {
        // Set up test addresses
        admin = makeAddr("admin");
        minter = makeAddr("minter");
        user = makeAddr("user");
        newMinter = makeAddr("newMinter");
        
        // Deploy implementation
        implementation = new LaunchpadToken();
        
        // Deploy proxy pointing to implementation
        bytes memory initData = abi.encodeCall(
            LaunchpadToken.initialize,
            (NAME, SYMBOL, admin, minter)
        );
        
        proxy = new ERC1967Proxy(address(implementation), initData);
        
        // Create a proxy wrapper for easier testing
        token = LaunchpadToken(address(proxy));
    }

    function test_InitialState() public view {
        assertEq(token.name(), NAME);
        assertEq(token.symbol(), SYMBOL);
        assertEq(token.totalSupply(), 0);
        bytes32 adminRole = token.DEFAULT_ADMIN_ROLE();
        bytes32 minterRole = token.MINTER_ROLE();
        bytes32 upgraderRole = token.UPGRADER_ROLE();
        
        assertTrue(token.hasRole(adminRole, admin));
        assertTrue(token.hasRole(minterRole, minter));
        assertTrue(token.hasRole(upgraderRole, admin));
    }

    function test_CannotReinitialize() public {
        vm.expectRevert();
        token.initialize(NAME, SYMBOL, admin, minter);
    }

    function test_MintByMinter() public {
        uint256 amount = 1000 * 10**18;
        
        vm.prank(minter);
        token.mint(user, amount);
        
        assertEq(token.balanceOf(user), amount);
        assertEq(token.totalSupply(), amount);
    }

    function test_CannotMintByNonMinter() public {
        uint256 amount = 1000 * 10**18;
        
        vm.prank(user);
        vm.expectRevert();
        token.mint(user, amount);
    }

    function test_CannotMintAboveCap() public {
        uint256 cap = 1_000_000_000 * 10**18;
        uint256 aboveCap = cap + 1;
        
        vm.prank(minter);
        vm.expectRevert();
        token.mint(user, aboveCap);
    }

    function test_ChangeMinter() public {
        bytes32 minterRole = token.MINTER_ROLE();
        
        // Admin can grant minter role to new address
        vm.startPrank(admin);
        token.grantRole(minterRole, newMinter);
        
        assertTrue(token.hasRole(minterRole, newMinter));
        
        // Admin can revoke minter role from old minter
        token.revokeRole(minterRole, minter);
        vm.stopPrank();
        
        assertFalse(token.hasRole(minterRole, minter));
        
        // New minter can mint
        uint256 amount = 1000 * 10**18;
        vm.prank(newMinter);
        token.mint(user, amount);
        
        assertEq(token.balanceOf(user), amount);
    }

    function test_CannotUpgradeByNonAdmin() public {
        address newImplementation = address(new LaunchpadToken());
        
        vm.prank(user);
        vm.expectRevert();
        token.upgradeToAndCall(newImplementation, "");
    }

    function test_UpgradeByAdmin() public {
        // Deploy new implementation
        LaunchpadToken newImplementation = new LaunchpadToken();
        
        // Upgrade to new implementation
        vm.prank(admin);
        token.upgradeToAndCall(address(newImplementation), "");
        
        // Functionality should still work after upgrade
        uint256 amount = 1000 * 10**18;
        vm.prank(minter);
        token.mint(user, amount);
        
        assertEq(token.balanceOf(user), amount);
    }
} 