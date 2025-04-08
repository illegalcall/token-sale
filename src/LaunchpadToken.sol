// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20CappedUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title LaunchpadToken
 * @dev Implements an upgradeable ERC20 token with a cap of 1 billion tokens.
 * Uses the UUPS proxy pattern for upgradeability.
 * Includes role-based access control for minting permissions.
 */
contract LaunchpadToken is 
    Initializable, 
    ERC20Upgradeable, 
    ERC20CappedUpgradeable, 
    AccessControlUpgradeable, 
    UUPSUpgradeable 
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    
    // 1 billion tokens with 18 decimals
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10**18;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializes the token with a name, symbol, and grants the admin, minter and upgrader roles to the specified addresses.
     * @param name_ The name of the token
     * @param symbol_ The symbol of the token
     * @param admin The address that will be granted the DEFAULT_ADMIN_ROLE
     * @param minter The address that will be granted the MINTER_ROLE (typically the sale contract)
     */
    function initialize(
        string memory name_,
        string memory symbol_,
        address admin,
        address minter
    ) public initializer {
        __ERC20_init(name_, symbol_);
        __ERC20Capped_init(MAX_SUPPLY);
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, minter);
        _grantRole(UPGRADER_ROLE, admin);
    }

    /**
     * @dev Creates `amount` new tokens for `to`.
     * @param to The address that will receive the minted tokens
     * @param amount The amount of tokens to mint
     * 
     * Requirements:
     * - the caller must have the `MINTER_ROLE`
     */
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    /**
     * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract.
     * Called by {UUPSUpgradeable-_authorizeUpgrade}.
     * @param newImplementation The address of the new implementation contract
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    // The following functions are overrides required by Solidity

    function _update(address from, address to, uint256 amount) internal override(ERC20Upgradeable, ERC20CappedUpgradeable) {
        super._update(from, to, amount);
    }
} 