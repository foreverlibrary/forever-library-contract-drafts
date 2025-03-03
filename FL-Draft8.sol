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
contract Forever Library is ERC721, ReentrancyGuard {
    using Strings for uint256;

    // Immutable contract configuration
    string public constant VERSION = "1.0.0";
    address public immutable DEPLOYER;

    // Gas optimized counter
    uint256 private _currentTokenId;

    // Collection metadata
    string private _collectionName;
    string private _collectionDescription;
    string private _collectionImage;

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
        
        // Set collection metadata
        _collectionName = "Forever Library";
        _collectionDescription = "A fully immutable, non-upgradeable NFT contract with open minting and permanent metadata.";
        
        // Set collection image (SVG logo)
        _collectionImage = "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMzY1LjMiIGhlaWdodD0iMTM2NS4zIiB2aWV3Qm94PSIwIDAgMTAyNCAxMDI0Ij48cGF0aCBkPSJNMCAwaDEwMjR2MTAyNEgwVjBaIi8+PHBhdGggZmlsbD0iI2ZmZiIgZD0iTTY0OSAyMzNhNjMgNjMgMCAwIDEgNTEgNTFjMiAxMS0yIDIyLTExIDI5LTQgNC0xMiA0LTE3IDEtMy0yLTUtNi00LTEwIDAtNSAyLTkgNC0xNHMyLTExIDAtMTZjLTItOS03LTE4LTE0LTI0LTYtNS0xMy05LTIwLTktMTIgMC0yMyAzLTMzIDktMTEgNy0yMCAxOS0yNSAzMS0xMCAyMi0xNCA0NS0xNiA2OWwtMTQgMTI2LTEgMTMgMzQtMjMgMTAtOWM1LTkgNy0yMCA0LTMxLTEtNi0zLTEzIDEtMTkgMy01IDktNiAxNC00IDUgMSA4IDUgMTAgOSA1IDkgNCAyMi0xIDMxLTMgNy05IDEyLTE1IDE2LTE2IDEzLTMyIDI1LTQ5IDM2bC05IDYtMSA2LTggNzZjLTIgMjYtNiA1MS0xNCA3Ni04IDI4LTIxIDUzLTM5IDc1bC0yMCAyM2MtMTUgMTUtMzMgMjgtNTQgMzRhNjcgNjcgMCAwIDEtNzYtMjggODAgODAgMCAwIDEtMTEtNTBjMS0xNiAzLTMxIDgtNDYgNC0xMyAxMS0yNCAxOS0zNSAxMS0xNSAyNS0yOCAzOS00MGwzMy0yMiA0OS0zMWMxLTEgNC0yIDQtNGwyLTE0IDE5LTE4MCAzLTIxYzItMTAgNi0yMCAxMS0yOSAxMS0xOCAyOC0zMSA0Ni00MmExMzYgMTM2IDAgMCAxIDkxLTE2WiIvPjxwYXRoIGQ9Im00NzUgNTQ5LTEgMTgtMTggMTYzYy0xIDctMSAxNC01IDIwLTUgMTAtMTUgMTgtMjUgMjMtOSA1LTE5IDctMjkgNS00IDAtMTAtMi0xMS03LTItMyAwLTggMC0xMmwxNS0xMzggMy0xOGMyLTUgNS05IDktMTMgNS01IDExLTggMTctMTJsMjktMTkgMTYtMTBaIi8+PC9zdmc+";
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
    
    // Collection metadata URI for marketplaces
    function contractURI() public view returns (string memory) {
        return string(
            abi.encodePacked(
                'data:application/json;base64,',
                Base64.encode(
                    bytes(
                        abi.encodePacked(
                            '{"name":"', _collectionName,
                            '","description":"', _collectionDescription,
                            '","image":"', _collectionImage,
                            '"}'
                        )
                    )
                )
            )
        );
    }

    receive() external payable {
        revert EtherNotAccepted();
    }

    fallback() external payable {
        revert EtherNotAccepted();
    }
}

// Base64 encoding library
library Base64 {
    string internal constant TABLE = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

    function encode(bytes memory data) internal pure returns (string memory) {
        uint256 len = data.length;
        if (len == 0) return '';
        
        // multiply by 4/3 rounded up
        uint256 encodedLen = 4 * ((len + 2) / 3);
        
        // Add some extra buffer at the end
        bytes memory result = new bytes(encodedLen + 32);

        bytes memory table = bytes(TABLE);

        assembly {
            let tablePtr := add(table, 1)
            let resultPtr := add(result, 32)

            for {
                let i := 0
            } lt(i, len) {

            } {
                i := add(i, 3)
                let input := and(mload(add(data, i)), 0xffffff)

                let out := mload(add(tablePtr, and(shr(18, input), 0x3F)))
                out := shl(8, out)
                out := add(out, and(mload(add(tablePtr, and(shr(12, input), 0x3F))), 0xFF))
                out := shl(8, out)
                out := add(out, and(mload(add(tablePtr, and(shr(6, input), 0x3F))), 0xFF))
                out := shl(8, out)
                out := add(out, and(mload(add(tablePtr, and(input, 0x3F))), 0xFF))
                out := shl(224, out)

                mstore(resultPtr, out)

                resultPtr := add(resultPtr, 4)
            }

            switch mod(len, 3)
            case 1 {
                mstore(sub(resultPtr, 2), shl(240, 0x3d3d))
            }
            case 2 {
                mstore(sub(resultPtr, 1), shl(248, 0x3d))
            }

            mstore(result, encodedLen)
        }

        return string(result);
    }
}
