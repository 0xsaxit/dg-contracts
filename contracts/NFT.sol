pragma solidity ^0.5.14;

import "@openzeppelin/contracts/token/ERC721/ERC721Full.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721Metadata.sol";
import "@openzeppelin/contracts/access/roles/MinterRole.sol";
import "./Strings.sol";

contract NFT is ERC721Full, MinterRole {
    using Strings for string;

    event NewToken(address indexed owner, string tokenName, uint256 tokenId);
    event BaseURIUpdated(address updater, string newURI);

    // Token properties
    struct Token {
        string name;
        string architecture;
        uint256 landParcels;
        uint256 version;
        uint256 supply;
        uint256 revenueShare;
        uint256 levels;
    }
    // Store each token's details
    mapping(uint256 => Token) public tokenDetails;

    /// @notice contract initialization
    /// @dev set the common base url for all tokens' metadata
    /// @param baseURI string that represent base url for token metadata
    constructor(string memory baseURI)
        public
        ERC721Full("Decentral Games Casinos", "DGC")
    {
        _setBaseURI(baseURI);
    }

    /// @notice change token base URI
    /// @dev should avoid using this function
    /// @param baseURI string that represent base url for token metadata
    function updateBaseURI(string calldata baseURI) external onlyMinter {
        _setBaseURI(baseURI);
        emit BaseURIUpdated(msg.sender, baseURI);
    }

    /// @notice get full token path to JSON file
    /// @dev override default function for getting token URI
    /// @param tokenId id of the token to query
    function tokenURI(uint256 tokenId) external view returns (string memory) {
        require(
            tokenId <= totalSupply() && tokenId > 0,
            "Token does not exist"
        );
        return Strings.strConcat(baseURI(), Strings.uint2str(tokenId));
    }

    /// @notice creates a new token
    /// @dev token id 0 does not exists
    function create(
        address to,
        string calldata name,
        string calldata architecture,
        uint256 landParcels,
        uint256 version,
        uint256 supply,
        uint256 revenueShare,
        uint256 levels
    ) external onlyMinter returns (uint256) {
        uint256 tokenId = totalSupply() + 1;
        _safeMint(to, tokenId);

        tokenDetails[tokenId] = Token(
            name,
            architecture,
            landParcels,
            version,
            supply,
            revenueShare,
            levels
        );

        emit NewToken(to, name, tokenId);
    }

    /// @notice update token info
    /// @dev token id 0 does not exists
    function updateTokenDetails(
        uint256 tokenId,
        string calldata name,
        string calldata architecture,
        uint256 landParcels,
        uint256 version,
        uint256 supply,
        uint256 revenueShare,
        uint256 levels
    ) external onlyMinter {
        require(ownerOf(tokenId) == msg.sender, "You dont own this token");

        tokenDetails[tokenId] = Token(
            name,
            architecture,
            landParcels,
            version,
            supply,
            revenueShare,
            levels
        );
    }
}
