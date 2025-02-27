// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

// External renderer interface
interface IExternalRenderer {
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

/// @title Forever Library
/// @notice A fully immutable, non-upgradeable NFT contract with open minting and permanent metadata.
contract ForeverLibrary is ERC721, ReentrancyGuard {
    using Strings for uint256;

    // Immutable contract configuration
    string public constant VERSION = "1.0.0";
    address public immutable DEPLOYER;

    // Gas optimized counter
    uint256 private _currentTokenId;

    // Optimized struct packing (Now includes creator)
    struct MintData {
        address creator;       // 20 bytes
        uint64 timestamp;      // 8 bytes
        uint64 blockNumber;    // 8 bytes
        bytes32 metadataHash;  // 32 bytes
        string tokenURI;       // dynamic
    }

    // State mappings
    mapping(uint256 => MintData) private _mintData;
    mapping(uint256 => uint256) public mintTimestamp; // Track minting timestamps for immutability enforcement

    // External metadata renderer settings per token
    mapping(uint256 => bool) public usesExternalRenderer;
    mapping(uint256 => address) public externalRendererAddresses;

    // Events
    event TokenMinted(
        address indexed creator,
        uint256 indexed tokenId,
        address indexed minter,
        string tokenURI,
        bytes32 metadataHash,
        bytes32 contentHash,
        uint256 timestamp,
        uint256 blockNumber
    );

    // Custom errors
    error EmptyURI();
    error TokenDoesNotExist();
    error URITooLong();
    error EtherNotAccepted();

    constructor() ERC721("Forever Library", "FL") {
        // Set immutable values
        DEPLOYER = msg.sender;
                
        // Start token IDs at 1
        _currentTokenId = 1;
    }

    modifier onlyTokenCreator(uint256 tokenId) {
        require(_mintData[tokenId].creator == msg.sender, "Only token creator can modify");
        _;
    }

    function mint(
        string calldata finalTokenURI,
        bytes32 contentHash
    ) external nonReentrant {
        // Validate input
        if (bytes(finalTokenURI).length == 0) revert EmptyURI();
        if (bytes(finalTokenURI).length > 2048) revert URITooLong();

        // Get current token ID and increment
        uint256 tokenId = _currentTokenId;
        unchecked {
            _currentTokenId++;
        }

        // Store mint data with timestamp
        _mintData[tokenId] = MintData({
            creator: msg.sender,
            timestamp: uint64(block.timestamp),
            blockNumber: uint64(block.number),
            metadataHash: keccak256(bytes(finalTokenURI)),
            tokenURI: finalTokenURI
        });

        mintTimestamp[tokenId] = block.timestamp; // Store the minting time

        // Mint NFT
        _safeMint(msg.sender, tokenId);

        // Emit event including contentHash
        emit TokenMinted(
            msg.sender,
            tokenId,
            msg.sender,
            finalTokenURI,
            keccak256(bytes(finalTokenURI)),
            contentHash,
            block.timestamp,
            block.number
        );
    }

    function setExternalRenderer(uint256 tokenId, address renderer) external onlyTokenCreator(tokenId) {
        require(renderer != address(0), "Invalid renderer address");
        require(block.timestamp <= mintTimestamp[tokenId] + 24 hours, "Metadata locked after 24 hours");

        externalRendererAddresses[tokenId] = renderer;
    }

    function toggleExternalRenderer(uint256 tokenId, bool enabled) external onlyTokenCreator(tokenId) {
        require(block.timestamp <= mintTimestamp[tokenId] + 24 hours, "Metadata locked after 24 hours");

        usesExternalRenderer[tokenId] = enabled;
    }

    function tokenURI(uint256 tokenId) 
        public 
        view 
        override 
        returns (string memory) 
    {
        // This will automatically revert if the token doesn't exist
        // The ERC721 implementation of ownerOf already handles this check
        ownerOf(tokenId); // Just call it for the side effect (will revert if token doesn't exist)
        
        // Check if metadata is still within the 24-hour window
        bool metadataLocked = block.timestamp > mintTimestamp[tokenId] + 24 hours;

        // Use external renderer if enabled for this token and within the 24-hour window
        if (usesExternalRenderer[tokenId] && externalRendererAddresses[tokenId] != address(0) && !metadataLocked) {
            return IExternalRenderer(externalRendererAddresses[tokenId]).tokenURI(tokenId);
        }

        // Return stored token URI (immutable after 24 hours)
        return _mintData[tokenId].tokenURI;
    }

    receive() external payable {
        revert EtherNotAccepted();
    }

    fallback() external payable {
        revert EtherNotAccepted();
    }
}
