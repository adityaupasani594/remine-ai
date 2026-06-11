// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title EWasteTransactions
 * @dev Production-ready smart contract for e-waste marketplace
 * 
 * Lightweight ERC-721 implementation focused ONLY on:
 * - Ownership transfer proof
 * - Transaction logging  
 * - Secure payments
 * - Lifecycle tracking (sell → buy → recycle)
 * 
 * NO metadata storage, NO IPFS, NO tokenURI
 * 
 * Roles:
 * - SELLER_ROLE: Can mint and list items
 * - RECYCLER_ROLE: Can buy and burn items
 */

contract EWasteTransactions is ERC721, ERC721Burnable, AccessControl, ReentrancyGuard {
    // ============ Role Definitions ============
    bytes32 public constant SELLER_ROLE = keccak256("SELLER_ROLE");
    bytes32 public constant RECYCLER_ROLE = keccak256("RECYCLER_ROLE");

    // ============ Storage (Minimal Only) ============
    uint256 private _tokenIdCounter = 0;
    
    mapping(uint256 _tokenId => uint256 price) public itemPrices;
    mapping(uint256 _tokenId => bool isListed) public listedItems;

    // ============ Events ============
    event ItemMinted(uint256 indexed tokenId, address indexed seller);
    event ItemListed(uint256 indexed tokenId, uint256 price);
    event ItemPurchased(uint256 indexed tokenId, address indexed seller, address indexed recycler, uint256 price);
    event ItemRecycled(uint256 indexed tokenId, address indexed recycler);

    // ============ Constructor ============
    /**
     * @dev Initialize contract with seller and recycler addresses
     * @param sellers Array of addresses to grant SELLER_ROLE
     * @param recyclers Array of addresses to grant RECYCLER_ROLE
     */
    constructor(address[] memory sellers, address[] memory recyclers) ERC721("EWasteTransactions", "EWASTE") {
        // Grant roles to initial sellers and recyclers
        for (uint256 i = 0; i < sellers.length; i++) {
            _grantRole(SELLER_ROLE, sellers[i]);
        }
        for (uint256 i = 0; i < recyclers.length; i++) {
            _grantRole(RECYCLER_ROLE, recyclers[i]);
        }
    }

    // ============ Mint Function (Seller Only) ============
    /**
     * @dev Mint a new e-waste item as ERC-721 token
     * Only sellers can mint items
     * 
     * @return tokenId The ID of the newly minted token
     */
    function mintItem() external onlyRole(SELLER_ROLE) returns (uint256) {
        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter++;
        
        _safeMint(msg.sender, tokenId);
        
        emit ItemMinted(tokenId, msg.sender);
        return tokenId;
    }

    // ============ Listing Function (Seller Only) ============
    /**
     * @dev List an item for sale
     * Only the token owner (seller) can list
     * 
     * @param tokenId ID of the token to list
     * @param price Price in Wei
     */
    function listItem(uint256 tokenId, uint256 price) external nonReentrant {
        require(ownerOf(tokenId) == msg.sender, "Only token owner can list");
        require(price > 0, "Price must be greater than 0");
        require(!listedItems[tokenId], "Item already listed");
        
        itemPrices[tokenId] = price;
        listedItems[tokenId] = true;
        
        emit ItemListed(tokenId, price);
    }

    // ============ Purchase Function (Recycler Only) ============
    /**
     * @dev Purchase an e-waste item
     * Only verified recyclers can buy
     * 
     * Transfers:
     * - NFT ownership from seller to recycler
     * - ETH payment from recycler to seller
     * 
     * @param tokenId ID of the token to purchase
     */
    function buyItem(uint256 tokenId) external payable onlyRole(RECYCLER_ROLE) nonReentrant {
        require(listedItems[tokenId], "Item is not listed for sale");
        require(msg.value == itemPrices[tokenId], "Incorrect payment amount");
        
        address seller = ownerOf(tokenId);
        uint256 price = itemPrices[tokenId];
        
        // Delist item
        listedItems[tokenId] = false;
        
        // Transfer NFT ownership
        _transfer(seller, msg.sender, tokenId);
        
        // Transfer payment to seller (using call for security)
        (bool success, ) = payable(seller).call{value: price}("");
        require(success, "Payment transfer failed");
        
        emit ItemPurchased(tokenId, seller, msg.sender, price);
    }

    // ============ Recycling Function (Recycler Only) ============
    /**
     * @dev Burn an item after recycling is complete
     * Only the current owner (recycler) can burn
     * Marks lifecycle as complete
     * 
     * @param tokenId ID of the token to burn
     */
    function burnAfterRecycle(uint256 tokenId) external nonReentrant {
        require(ownerOf(tokenId) == msg.sender, "Only token owner can burn");
        require(hasRole(RECYCLER_ROLE, msg.sender), "Only recyclers can burn items");
        
        _burn(tokenId);
        listedItems[tokenId] = false;
        
        emit ItemRecycled(tokenId, msg.sender);
    }

    // ============ Query Functions ============
    /**
     * @dev Get current item count
     * @return Current token ID counter
     */
    function getCurrentTokenId() external view returns (uint256) {
        return _tokenIdCounter;
    }

    /**
     * @dev Check if item is listed
     * @param tokenId ID of the token
     * @return Boolean indicating if listed
     */
    function isItemListed(uint256 tokenId) external view returns (bool) {
        return listedItems[tokenId];
    }

    /**
     * @dev Get item price
     * @param tokenId ID of the token
     * @return Price in Wei
     */
    function getItemPrice(uint256 tokenId) external view returns (uint256) {
        return itemPrices[tokenId];
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
