// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {Nonces} from "lib/openzeppelin-contracts/contracts/utils/Nonces.sol";

/**
 * @title ShadowPoolGovernanceToken
 * @dev Governance token for ShadowPool DAO with voting delegation capabilities
 */
contract ShadowPoolGovernanceToken is ERC20, ERC20Permit, ERC20Votes, Ownable {
    /// @notice Maximum supply of governance tokens
    uint256 public constant MAX_SUPPLY = 1_000_000 * 10 ** 18; // 1 million tokens

    /// @notice Whether minting is enabled
    bool public mintingEnabled;

    /// @notice Minters mapping
    mapping(address => bool) public minters;

    /// @notice Events
    event MintingEnabled(address indexed enabler);
    event MintingDisabled(address indexed disabler);
    event MinterAdded(address indexed minter);
    event MinterRemoved(address indexed minter);

    /// @notice Errors
    error Token__MintingDisabled();
    error Token__MaxSupplyExceeded();
    error Token__NotMinter();
    error Token__InvalidAmount();

    /// @notice Constructor
    /// @param initialOwner Initial owner address
    /// @param initialSupply Initial token supply
    constructor(address initialOwner, uint256 initialSupply)
        ERC20("ShadowPool Governance", "SPG")
        ERC20Permit("ShadowPool Governance")
        Ownable(initialOwner)
    {
        if (initialSupply > MAX_SUPPLY) {
            revert Token__MaxSupplyExceeded();
        }

        if (initialSupply > 0) {
            _mint(initialOwner, initialSupply);
        }

        minters[initialOwner] = true;
        mintingEnabled = true;
    }

    /// @notice Enable minting (only owner)
    function enableMinting() external onlyOwner {
        mintingEnabled = true;
        emit MintingEnabled(msg.sender);
    }

    /// @notice Disable minting (only owner)
    function disableMinting() external onlyOwner {
        mintingEnabled = false;
        emit MintingDisabled(msg.sender);
    }

    /// @notice Add minter (only owner)
    /// @param minter Address to add as minter
    function addMinter(address minter) external onlyOwner {
        minters[minter] = true;
        emit MinterAdded(minter);
    }

    /// @notice Remove minter (only owner)
    /// @param minter Address to remove as minter
    function removeMinter(address minter) external onlyOwner {
        minters[minter] = false;
        emit MinterRemoved(minter);
    }

    /// @notice Mint tokens (only minters)
    /// @param to Recipient address
    /// @param amount Amount to mint
    function mint(address to, uint256 amount) external {
        if (!minters[msg.sender]) {
            revert Token__NotMinter();
        }

        if (!mintingEnabled) {
            revert Token__MintingDisabled();
        }

        if (amount == 0) {
            revert Token__InvalidAmount();
        }

        if (totalSupply() + amount > MAX_SUPPLY) {
            revert Token__MaxSupplyExceeded();
        }

        _mint(to, amount);
    }

    /// @notice Burn tokens from caller
    /// @param amount Amount to burn
    function burn(uint256 amount) external {
        if (amount == 0) {
            revert Token__InvalidAmount();
        }

        _burn(msg.sender, amount);
    }

    /// @notice Burn tokens from specified address (only owner)
    /// @param from Address to burn from
    /// @param amount Amount to burn
    function burnFrom(address from, uint256 amount) external onlyOwner {
        if (amount == 0) {
            revert Token__InvalidAmount();
        }

        _burn(from, amount);
    }

    // Override required functions for ERC20Votes
    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }

    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
