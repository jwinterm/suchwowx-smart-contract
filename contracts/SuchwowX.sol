// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract SuchwowX is ERC721, ERC721URIStorage, Ownable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenSupply;

    // Data to maintain
    mapping (uint256 => address) public tokenCreator;
    mapping (uint256 => string) public tokenMetadata;
    mapping (uint256 => uint256) public tokenTips;
    mapping (address => uint256) public creatorTips;
    mapping (address => uint256) public creatorTokensMinted;
    mapping (address => uint256) public tipperTips;

    // Define starting contract state
    string public baseURI = "";

    constructor() ERC721("SuchwowX", "SWX") {}

    // Withdraw contract balance to creator (mnemonic seed address 0)
    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    // Get total supply based upon counter
    function totalSupply() public view returns (uint256) {
        return _tokenSupply.current();
    }

    // Mint a new token with a specific metadata hash location
    function mint(string memory metadataIPFSHash) external {
        uint256 tokenId = totalSupply() + 1; // Start at 1
        _safeMint(msg.sender, tokenId);
        _tokenSupply.increment();
        tokenCreator[tokenId] = msg.sender;
        tokenMetadata[tokenId] = metadataIPFSHash;
        creatorTokensMinted[msg.sender] = creatorTokensMinted[msg.sender].add(1);
    }

    // Tip a token and it's creator
    function tip(uint256 tokenId) public payable {
        address creator = tokenCreator[tokenId];
        tokenTips[tokenId] = tokenTips[tokenId].add(msg.value);
        creatorTips[creator] = creatorTips[creator].add(msg.value);
        tipperTips[creator] = tipperTips[creator].add(msg.value);
        payable(creator).transfer(msg.value);
    }

    // Override the below functions from parent contracts

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        // Each token should return a unique IPFS hash
        return string(abi.encodePacked("ipfs://", tokenMetadata[tokenId]));
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        
    }
}