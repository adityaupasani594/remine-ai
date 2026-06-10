// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title GreenCredits
 * @dev ERC-20 token for rewarding users who recycle e-waste
 * 
 * Features:
 * - Only MINTER_ROLE can mint new credits
 * - Rewards issued after deal completion
 * - Standard ERC-20 transfer capabilities
 * - Secure and gas-optimized
 */

contract GreenCredits is ERC20, AccessControl, ReentrancyGuard {
    // ============ Role Definitions ============
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    
    // ============ Constants ============
    uint256 public constant DECIMALS = 18;
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * (10 ** DECIMALS); // 1 billion tokens max
    
    // ============ Storage ============
    uint256 private _totalMintedCredits = 0;
    
    // ============ Events ============
    event CreditsMinted(address indexed user, uint256 amount, string reason);
    event CreditsTransferred(address indexed from, address indexed to, uint256 amount);
    
    // ============ Constructor ============
    /**
     * @dev Initialize the GreenCredits token
     * @param initialMinter Address that will have MINTER_ROLE
     */
    constructor(address initialMinter) ERC20("Green Credits", "GREEN") {
        require(initialMinter != address(0), "Invalid minter address");
        
        // Grant roles
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, initialMinter);
    }
    
    // ============ Minting Function (MINTER_ROLE Only) ============
    /**
     * @dev Mint new GREEN tokens as rewards
     * Only MINTER_ROLE can call this
     * 
     * @param to Address to receive the tokens
     * @param amount Amount of tokens to mint (in wei, 1 token = 10^18 wei)
     * @param reason Description of why credits were minted (e.g., "recycle_complete")
     * 
     * @return Boolean indicating success
     */
    function mintCredits(
        address to, 
        uint256 amount, 
        string calldata reason
    ) external onlyRole(MINTER_ROLE) nonReentrant returns (bool) {
        require(to != address(0), "Cannot mint to zero address");
        require(amount > 0, "Amount must be greater than 0");
        require(_totalMintedCredits + amount <= MAX_SUPPLY, "Exceeds maximum supply");
        
        _totalMintedCredits += amount;
        _mint(to, amount);
        
        emit CreditsMinted(to, amount, reason);
        return true;
    }
    
    // ============ Burn Function (User Can Burn Own Tokens) ============
    /**
     * @dev Burn (destroy) your own tokens
     * @param amount Amount of tokens to burn
     */
    function burnCredits(uint256 amount) external returns (bool) {
        require(amount > 0, "Amount must be greater than 0");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        
        _burn(msg.sender, amount);
        return true;
    }
    
    // ============ Transfer Overrides (With Event Logging) ============
    /**
     * @dev Override transfer to emit custom event
     */
    function transfer(address to, uint256 amount) 
        public 
        override 
        returns (bool) 
    {
        require(to != address(0), "Cannot transfer to zero address");
        require(amount > 0, "Amount must be greater than 0");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        
        bool success = super.transfer(to, amount);
        
        if (success) {
            emit CreditsTransferred(msg.sender, to, amount);
        }
        
        return success;
    }
    
    /**
     * @dev Override transferFrom to emit custom event
     */
    function transferFrom(
        address from, 
        address to, 
        uint256 amount
    ) public override returns (bool) {
        require(to != address(0), "Cannot transfer to zero address");
        require(amount > 0, "Amount must be greater than 0");
        
        bool success = super.transferFrom(from, to, amount);
        
        if (success) {
            emit CreditsTransferred(from, to, amount);
        }
        
        return success;
    }
    
    // ============ Query Functions ============
    /**
     * @dev Get total tokens minted so far
     * @return Total amount of tokens ever minted
     */
    function getTotalMintedCredits() external view returns (uint256) {
        return _totalMintedCredits;
    }
    
    /**
     * @dev Get remaining mintable tokens
     * @return Amount of tokens still available to mint
     */
    function getRemainingMintableCredits() external view returns (uint256) {
        return MAX_SUPPLY - _totalMintedCredits;
    }
    
    /**
     * @dev Check if an address has MINTER_ROLE
     * @param account Address to check
     * @return Boolean indicating if address is a minter
     */
    function isMinter(address account) external view returns (bool) {
        return hasRole(MINTER_ROLE, account);
    }
    
    /**
     * @dev Get user's token balance in human-readable format
     * @param account Address to check
     * @return Balance in GREEN tokens (not wei)
     */
    function getFormattedBalance(address account) external view returns (uint256) {
        return balanceOf(account) / (10 ** DECIMALS);
    }
    
    // ============ ERC165 Support ============
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
