// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC2981.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/// @title ForeverLibrary NFT Contract
/// @notice This contract implements a fully immutable NFT collection
contract ForeverLibrary is ERC721URIStorage, ERC2981, ReentrancyGuard {
    using Counters for Counters.Counter;
    using Strings for uint256;

    string private immutable _contractMetadataURI;
    string private immutable _baseTokenURI;
    string public constant VERSION = "1.0.0";
    
    Counters.Counter private _tokenIdCounter;
    
    struct MintData {
        uint64 timestamp;
        uint64 blockNumber;
        bytes32 metadataHash;
        bytes32 contentHash;
    }

    mapping(uint256 => MintData) private _mintData;
    mapping(uint256 => address) private _creators;
    mapping(address => uint256[]) private _ownedTokens;
    mapping(address => mapping(uint256 => uint256)) private _ownedTokenIndex;

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

    error InvalidAddress();
    error InvalidRoyaltyFee();
    error EmptyURI();
    error TokenDoesNotExist();
    error ContractAlreadyInitialized();
    error EtherNotAccepted();

    constructor(
        string memory name,
        string memory symbol,
        string memory contractURI,
        string memory baseURI,
        address defaultRoyaltyReceiver,
        uint96 defaultRoyaltyFee
    ) ERC721(name, symbol) {
        if (bytes(contractURI).length == 0) revert EmptyURI();
        if (bytes(baseURI).length == 0) revert EmptyURI();
        if (defaultRoyaltyReceiver == address(0)) revert InvalidAddress();
        if (defaultRoyaltyFee > 10000) revert InvalidRoyaltyFee();
        
        _contractMetadataURI = contractURI;
        _baseTokenURI = baseURI;
        _setDefaultRoyalty(defaultRoyaltyReceiver, defaultRoyaltyFee);
        
        _tokenIdCounter.increment(); // Start token IDs at 1
    }

    function mint(
        string calldata tokenURI,
        bytes32 contentHash,
        uint96 royaltyFee
    ) external nonReentrant {
        if (bytes(tokenURI).length == 0) revert EmptyURI();
        if (royaltyFee > 10000) revert InvalidRoyaltyFee();

        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();

        _mintData[tokenId] = MintData({
            timestamp: uint64(block.timestamp),
            blockNumber: uint64(block.number),
            metadataHash: keccak256(bytes(tokenURI)),
            contentHash: contentHash
        });

        _creators[tokenId] = msg.sender;
        
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, tokenURI);
        _setTokenRoyalty(tokenId, msg.sender, royaltyFee);

        _ownedTokenIndex[msg.sender][tokenId] = _ownedTokens[msg.sender].length;
        _ownedTokens[msg.sender].push(tokenId);

        emit TokenMinted(
            msg.sender,
            tokenId,
            msg.sender,
            tokenURI,
            keccak256(bytes(tokenURI)),
            contentHash,
            block.timestamp,
            block.number
        );
    }

    function _baseURI() internal view virtual override returns (string memory) {
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
            bytes32 contentHash
        ) 
    {
        if (!_exists(tokenId)) revert TokenDoesNotExist();
        MintData memory data = _mintData[tokenId];
        return (
            _creators[tokenId],
            data.timestamp,
            data.blockNumber,
            data.metadataHash,
            data.contentHash
        );
    }

    function getOwnedTokens(address owner) external view returns (uint256[] memory) {
        if (owner == address(0)) revert InvalidAddress();
        return _ownedTokens[owner];
    }

    function contractURI() external view returns (string memory) {
        return _contractMetadataURI;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721URIStorage, ERC2981)
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
