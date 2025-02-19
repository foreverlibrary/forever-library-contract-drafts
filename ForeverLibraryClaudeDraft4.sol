// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC2981.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/// @title ForeverLibrary NFT Contract
/// @notice This contract implements a fully immutable NFT collection
/// @dev Metadata is set at mint time and cannot be changed
contract ForeverLibrary is ERC721, ERC2981, ReentrancyGuard {
    using Counters for Counters.Counter;
    using Strings for uint256;

    // Immutable contract configuration
    string private immutable _contractMetadataURI;
    string private immutable _baseTokenURI;
    string public constant VERSION = "1.0.0";
    address public immutable CREATOR;
    
    // Counter for token IDs
    Counters.Counter private _tokenIdCounter;

    // Optimized struct packing
    struct MintData {
        uint64 timestamp;      // 8 bytes
        uint64 blockNumber;    // 8 bytes
        bytes32 metadataHash;  // 32 bytes
        bytes32 contentHash;   // 32 bytes
        string tokenURI;       // dynamic
    }

    // State mappings
    mapping(uint256 => MintData) private _mintData;
    mapping(uint256 => address) private _creators;
    mapping(address => uint256[]) private _ownedTokens;
    mapping(address => mapping(uint256 => uint256)) private _ownedTokenIndex;

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
    error InvalidAddress();
    error InvalidRoyaltyFee();
    error EmptyURI();
    error TokenDoesNotExist();
    error URITooLong();
    error TokenAlreadyMinted();
    error OnlyCreatorAllowed();
    error EtherNotAccepted();

    constructor(
        string memory name,
        string memory symbol,
        string memory contractURI,
        string memory baseURI,
        address defaultRoyaltyReceiver,
        uint96 defaultRoyaltyFee
    ) ERC721(name, symbol) {
        // Input validation
        if (bytes(contractURI).length == 0) revert EmptyURI();
        if (bytes(baseURI).length == 0) revert EmptyURI();
        if (defaultRoyaltyReceiver == address(0)) revert InvalidAddress();
        if (defaultRoyaltyFee > 10000) revert InvalidRoyaltyFee();

        // URI length validation
        if (bytes(contractURI).length > 2048) revert URITooLong();
        if (bytes(baseURI).length > 2048) revert URITooLong();
        
        // Set immutable values
        _contractMetadataURI = contractURI;
        _baseTokenURI = baseURI;
        CREATOR = msg.sender;

        // Set royalty info
        _setDefaultRoyalty(defaultRoyaltyReceiver, defaultRoyaltyFee);
        
        // Start token IDs at 1
        _tokenIdCounter.increment();
    }

    function mint(
        string calldata finalTokenURI,
        bytes32 contentHash,
        uint96 royaltyFee
    ) external nonReentrant {
        // Only creator can mint
        if (msg.sender != CREATOR) revert OnlyCreatorAllowed();
        
        // Validate input
        if (bytes(finalTokenURI).length == 0) revert EmptyURI();
        if (bytes(finalTokenURI).length > 2048) revert URITooLong();
        if (royaltyFee > 10000) revert InvalidRoyaltyFee();

        // Get and increment token ID
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        
        // Validate token
        if (_exists(tokenId)) revert TokenAlreadyMinted();

        // Update state before external calls
        _creators[tokenId] = msg.sender;
        _ownedTokenIndex[msg.sender][tokenId] = _ownedTokens[msg.sender].length;
        _ownedTokens[msg.sender].push(tokenId);

        // Store mint data with final metadata
        _mintData[tokenId] = MintData({
            timestamp: uint64(block.timestamp),
            blockNumber: uint64(block.number),
            metadataHash: keccak256(bytes(finalTokenURI)),
            contentHash: contentHash,
            tokenURI: finalTokenURI
        });

        // External calls last (CEI pattern)
        _safeMint(msg.sender, tokenId);
        _setTokenRoyalty(tokenId, msg.sender, royaltyFee);

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
            _creators[tokenId],
            data.timestamp,
            data.blockNumber,
            data.metadataHash,
            data.contentHash,
            data.tokenURI
        );
    }

    function contractURI() 
        external 
        view 
        returns (string memory) 
    {
        return _contractMetadataURI;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    receive() external payable {
        revert EtherNotAccepted();
    }

    fallback() external payable {
        revert EtherNotAccepted();
    }
}
