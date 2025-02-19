// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/// @title ForeverLibrary NFT Contract
/// @notice A fully immutable, non-upgradeable NFT contract with open minting and permanent metadata.
contract ForeverLibrary is ERC721, ReentrancyGuard {
    using Strings for uint256;

    // Immutable contract configuration
    string private immutable _baseTokenURI;
    string public constant VERSION = "1.0.0";
    address public immutable CREATOR;

    // Gas optimized counter
    uint256 private _currentTokenId;

    // Optimized struct packing (Now includes creator)
    struct MintData {
        address creator;       // 20 bytes
        uint64 timestamp;      // 8 bytes
        uint64 blockNumber;    // 8 bytes
        bytes32 metadataHash;  // 32 bytes
        bytes32 contentHash;   // 32 bytes
        string tokenURI;       // dynamic
    }

    // State mappings
    mapping(uint256 => MintData) private _mintData;

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

    constructor(
        string memory name,
        string memory symbol,
        string memory baseURI
    ) ERC721(name, symbol) {
        // Input validation
        if (bytes(baseURI).length == 0) revert EmptyURI();
        if (bytes(baseURI).length > 2048) revert URITooLong();

        // Set immutable values
        _baseTokenURI = baseURI;
        CREATOR = msg.sender;
        
        // Start token IDs at 1
        _currentTokenId = 1;
    }

    function mint(
        string calldata finalTokenURI,
        bytes32 contentHash
    ) external nonReentrant {
        // Validate input
        if (bytes(finalTokenURI).length == 0) revert EmptyURI();
        if (bytes(finalTokenURI).length > 2048) revert URITooLong();

        // Get current token ID and increment
        uint256 tokenId = _currentTokenId++;

        // Store mint data with creator inside struct
        _mintData[tokenId] = MintData({
            creator: msg.sender,
            timestamp: uint64(block.timestamp),
            blockNumber: uint64(block.number),
            metadataHash: keccak256(bytes(finalTokenURI)),
            contentHash: contentHash,
            tokenURI: finalTokenURI
        });

        // Mint NFT
        _safeMint(msg.sender, tokenId);

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

    function tokenURI(uint256 tokenId) 
        public 
        view 
        virtual 
        override 
        returns (string memory) 
    {
        if (!_exists(tokenId)) revert TokenDoesNotExist();
        
        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? 
            string(abi.encodePacked(baseURI, _mintData[tokenId].tokenURI)) : 
            _mintData[tokenId].tokenURI;
    }

    function _baseURI() 
        internal 
        view 
        virtual 
        override 
        returns (string memory) 
    {
        return _baseTokenURI;
    }

    function getMintData(uint256 tokenId) 
        external 
        view 
        returns (
            address creator,
            uint64 timestamp,
            uint64 blockNumber,
            bytes32 metadataHash,
            bytes32 contentHash,
            string memory uri
        ) 
    {
        if (!_exists(tokenId)) revert TokenDoesNotExist();
        MintData memory data = _mintData[tokenId];
        return (
            data.creator, // Now retrieving from struct
            data.timestamp,
            data.blockNumber,
            data.metadataHash,
            data.contentHash,
            data.tokenURI
        );
    }

    /// @notice Verifies if a given metadata string matches the stored hash
    function verifyMetadata(uint256 tokenId, string calldata metadata) external view returns (bool) {
        if (!_exists(tokenId)) revert TokenDoesNotExist();
        return _mintData[tokenId].metadataHash == keccak256(bytes(metadata));
    }

    receive() external payable {
        revert EtherNotAccepted();
    }

    fallback() external payable {
        revert EtherNotAccepted();
    }
}
