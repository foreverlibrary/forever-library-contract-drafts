// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC2981.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract ForeverLibrary is ERC721URIStorage, ERC2981, ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;
    
    string private constant SIGNING_DOMAIN = "ForeverLibrary";
    string private constant SIGNATURE_VERSION = "1";
    string private _contractMetadataURI;
    
    mapping(uint256 => address) private _tokenCreators;
    mapping(uint256 => uint64) private _creationBlocks;
    mapping(uint256 => bytes32) private _metadataHashes;
    mapping(address => mapping(uint256 => uint256)) private _ownedTokenIndex;
    mapping(address => uint256[]) private _ownedTokens;
    
    event TokenMinted(address indexed minter, address indexed creator, uint256 indexed tokenId, string tokenURI);
    event TokenTransferred(address indexed from, address indexed to, uint256 indexed tokenId);

    constructor() ERC721("ForeverLibrary", "FLB") {}

    function mint(address to, string calldata uri, address royaltyReceiver, uint96 royaltyFee) external {
        require(to != address(0), "Cannot mint to zero address");
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        
        _safeMint(to, tokenId);
        _setTokenRoyalty(tokenId, royaltyReceiver, royaltyFee);
        
        _tokenCreators[tokenId] = msg.sender;
        _creationBlocks[tokenId] = uint64(block.number);
        _metadataHashes[tokenId] = keccak256(abi.encodePacked(uri));
        
        _ownedTokenIndex[to][tokenId] = _ownedTokens[to].length;
        _ownedTokens[to].push(tokenId);
        
        emit TokenMinted(to, msg.sender, tokenId, uri);
    }
    
    function _transfer(address from, address to, uint256 tokenId) internal override {
        super._transfer(from, to, tokenId);
        
        _removeTokenFromOwnerEnumeration(from, tokenId);
        _ownedTokenIndex[to][tokenId] = _ownedTokens[to].length;
        _ownedTokens[to].push(tokenId);
        
        emit TokenTransferred(from, to, tokenId);
    }
    
    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) private {
        uint256 lastTokenIndex = _ownedTokens[from].length - 1;
        uint256 tokenIndex = _ownedTokenIndex[from][tokenId];

        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];
            _ownedTokens[from][tokenIndex] = lastTokenId;
            _ownedTokenIndex[from][lastTokenId] = tokenIndex;
        }

        _ownedTokens[from].pop();
        delete _ownedTokenIndex[from][tokenId];
    }
    
    function getOwnedTokens(address owner) external view returns (uint256[] memory) {
        return _ownedTokens[owner];
    }
    
    function getTokenMetadata(uint256 tokenId) external view returns (address creator, uint256 creationBlock, bytes32 metadataHash) {
        require(_exists(tokenId), "Token does not exist");
        return (_tokenCreators[tokenId], _creationBlocks[tokenId], _metadataHashes[tokenId]);
    }
    
    function setContractURI(string calldata uri) external onlyOwner {
        _contractMetadataURI = uri;
    }

    function contractURI() external view returns (string memory) {
        return _contractMetadataURI;
    }
}
