// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title RecyclerBadge
 * @dev ERC-721 Soulbound NFT for recycler verification and achievements
 * 
 * Features:
 * - Non-transferable (Soulbound) - badges cannot be sold or transferred
 * - Only MINTER_ROLE can mint new badges
 * - Track verification status and achievement levels
 * - Different badge types: Verified Recycler, Top Recycler, Green Champion
 * - Perfect for reputation system
 */

contract RecyclerBadge is ERC721, AccessControl, ReentrancyGuard {
    // ============ Role Definitions ============
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    
    // ============ Badge Types ============
    enum BadgeType {
        VERIFIED_RECYCLER,    // 0 - Basic verification
        TOP_RECYCLER,         // 1 - 100+ completed recycling deals
        GREEN_CHAMPION,       // 2 - 500+ deals or environmental impact
        ECO_PIONEER           // 3 - Founding member or early adopter
    }
    
    // ============ Storage ============
    uint256 private _tokenIdCounter = 0;
    
    // Badge data storage
    mapping(uint256 tokenId => BadgeType badgeType) public tokenBadgeType;
    mapping(uint256 tokenId => string metadata) public tokenMetadata;
    mapping(address recycler => uint256[] tokenIds) public addressBadges;
    mapping(address recycler => bool verified) public verifiedRecyclers;
    
    // ============ Events ============
    event BadgeMinted(
        uint256 indexed tokenId, 
        address indexed recycler, 
        BadgeType badgeType, 
        string metadata
    );
    event BadgeBurned(uint256 indexed tokenId, address indexed recycler);
    event RecyclerVerified(address indexed recycler, uint256 indexed tokenId);
    event BadgeUpgraded(uint256 indexed tokenId, BadgeType from, BadgeType to);
    
    // ============ Constructor ============
    /**
     * @dev Initialize the RecyclerBadge contract
     * @param initialMinter Address that will have MINTER_ROLE
     */
    constructor(address initialMinter) ERC721("Recycler Badge", "RECYCLE") {
        require(initialMinter != address(0), "Invalid minter address");
        
        // Grant roles
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, initialMinter);
        _grantRole(BURNER_ROLE, initialMinter);
    }
    
    // ============ Minting Function (MINTER_ROLE Only) ============
    /**
     * @dev Mint a new badge for a recycler
     * Only MINTER_ROLE can call this
     * 
     * @param to Address of the recycler receiving the badge
     * @param badgeType Type of badge (0-3)
     * @param metadata Additional information about the badge
     * 
     * @return tokenId The ID of the minted badge NFT
     */
    function mintBadge(
        address to,
        BadgeType badgeType,
        string calldata metadata
    ) external onlyRole(MINTER_ROLE) nonReentrant returns (uint256) {
        require(to != address(0), "Cannot mint to zero address");
        require(bytes(metadata).length > 0, "Metadata cannot be empty");
        
        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter++;
        
        // Mint the NFT (soulbound to 'to' address)
        _safeMint(to, tokenId);
        
        // Store badge data
        tokenBadgeType[tokenId] = badgeType;
        tokenMetadata[tokenId] = metadata;
        addressBadges[to].push(tokenId);
        
        // Mark recycler as verified if this is first badge
        if (!verifiedRecyclers[to]) {
            verifiedRecyclers[to] = true;
            emit RecyclerVerified(to, tokenId);
        }
        
        emit BadgeMinted(tokenId, to, badgeType, metadata);
        return tokenId;
    }
    
    // ============ Burn Function (BURNER_ROLE Only) ============
    /**
     * @dev Burn a badge (remove it)
     * Only BURNER_ROLE can call this
     * 
     * @param tokenId ID of the badge to burn
     */
    function burnBadge(uint256 tokenId) external onlyRole(BURNER_ROLE) nonReentrant {
        require(_ownerOf(tokenId) != address(0), "Badge does not exist");
        
        address owner = _ownerOf(tokenId);
        string memory metadata = tokenMetadata[tokenId];
        
        // Remove from address badges array
        uint256[] storage badges = addressBadges[owner];
        for (uint256 i = 0; i < badges.length; i++) {
            if (badges[i] == tokenId) {
                badges[i] = badges[badges.length - 1];
                badges.pop();
                break;
            }
        }
        
        // Delete badge data
        delete tokenBadgeType[tokenId];
        delete tokenMetadata[tokenId];
        
        // Burn the NFT
        _burn(tokenId);
        
        emit BadgeBurned(tokenId, owner);
    }
    
    // ============ Soulbound (Non-Transferable) Overrides ============
    // These functions prevent token transfers
    
    /**
     * @dev Prevent token transfer via transferFrom
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override {
        revert("Soulbound: Badges cannot be transferred");
    }
    
    /**
     * @dev Prevent approval for transfer
     */
    function approve(address to, uint256 tokenId) 
        public 
        override
    {
        revert("Soulbound: Badges cannot be transferred");
    }
    
    /**
     * @dev Prevent approval for all transfers
     */
    function setApprovalForAll(address operator, bool approved) 
        public 
        override
    {
        revert("Soulbound: Badges cannot be transferred");
    }
    
    // ============ Query Functions ============
    /**
     * @dev Get all badges owned by an address
     * @param recycler Address to query
     * @return Array of token IDs
     */
    function getBadgesOfRecycler(address recycler) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return addressBadges[recycler];
    }
    
    /**
     * @dev Get number of badges owned by an address
     * @param recycler Address to query
     * @return Number of badges
     */
    function getBadgeCount(address recycler) external view returns (uint256) {
        return addressBadges[recycler].length;
    }
    
    /**
     * @dev Get badge type of a token
     * @param tokenId ID of the badge
     * @return Badge type (0-3)
     */
    function getBadgeType(uint256 tokenId) external view returns (BadgeType) {
        require(_ownerOf(tokenId) != address(0), "Badge does not exist");
        return tokenBadgeType[tokenId];
    }
    
    /**
     * @dev Get metadata of a badge
     * @param tokenId ID of the badge
     * @return Metadata string
     */
    function getBadgeMetadata(uint256 tokenId) external view returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Badge does not exist");
        return tokenMetadata[tokenId];
    }
    
    /**
     * @dev Get total badges minted
     * @return Total number of badges
     */
    function getTotalBadges() external view returns (uint256) {
        return _tokenIdCounter;
    }
    
    /**
     * @dev Check if recycler is verified
     * @param recycler Address to check
     * @return Boolean indicating verification status
     */
    function isVerifiedRecycler(address recycler) external view returns (bool) {
        return verifiedRecyclers[recycler];
    }
    
    /**
     * @dev Check if address has specific badge type
     * @param recycler Address to check
     * @param badgeType Type to look for
     * @return Boolean indicating if recycler has this badge type
     */
    function hasBadgeType(address recycler, BadgeType badgeType) 
        external 
        view 
        returns (bool) 
    {
        uint256[] memory badges = addressBadges[recycler];
        for (uint256 i = 0; i < badges.length; i++) {
            if (tokenBadgeType[badges[i]] == badgeType) {
                return true;
            }
        }
        return false;
    }
    
    /**
     * @dev Get badge type name as string
     * @param badgeType Type to convert
     * @return String name of badge type
     */
    function getBadgeTypeName(BadgeType badgeType) 
        public 
        pure 
        returns (string memory) 
    {
        if (badgeType == BadgeType.VERIFIED_RECYCLER) return "Verified Recycler";
        if (badgeType == BadgeType.TOP_RECYCLER) return "Top Recycler";
        if (badgeType == BadgeType.GREEN_CHAMPION) return "Green Champion";
        if (badgeType == BadgeType.ECO_PIONEER) return "Eco Pioneer";
        return "Unknown";
    }
    
    // ============ ERC165 Support ============
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
