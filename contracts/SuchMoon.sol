// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract SuchMOON is ERC721, ERC721URIStorage, Ownable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenSupply;

    // Structs to represent our data
    struct Post {
        uint256 publisherTipsETH;
        uint256 creatorTipsETH;
        uint256 publisherTipsMOON;
        uint256 creatorTipsMOON;
        address publisherAddress;
        address creatorAddress;
        string metadataIPFSHash;
    }

    struct User {
        string addressETH;
        string userHandle;
        string metadataIPFSHash;
        uint256 tippedETH;
        uint256 tippedMOON;
        uint256[] postsPublished;
        uint256[] postsCreated;
    }

    // Data to maintain
    mapping (uint256 => Post) public tokenPost;
    mapping (address => User) public userProfile;
    mapping (string => uint256) public metadataTokenId;
    mapping (string => bool) public postStatus;

    // Define starting contract state
    ERC20 MOON;
    address payable _owner;
    string public contractCreator = "jwinterm.eth";
    string public contractVersion = "v0.1";
    uint256 public publisherTipCutPercent = 25;

    uint256 mintPrice;

    constructor() ERC721("SuchMOON", "SMOON") {
        _owner = payable(msg.sender);
        MOON = ERC20(0x138fAFa28a05A38f4d2658b12b0971221A7d5728);
    }

    /************
    Contract Operations
    ************/

    function setMintPrice(uint256 _price) external onlyOwner {
        mintPrice = _price;
    }

    // Withdraw contract balance to creator (mnemonic seed address 0)
    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    // Specify new publisher tip cut (not to exceed 10%)
    function setPublisherTipCut(uint256 percent) public onlyOwner {
        require(percent <= 100, "Publisher tip cut cannot exceed 100%");
        publisherTipCutPercent = percent;
    }

    // Get total supply based upon counter
    function totalSupply() public view returns (uint256) {
        return _tokenSupply.current();
    }

    /************
    User Settings
    ************/

    // Specify new ETH address for user
    function setUserETHAddress(string memory addressETH) external {
        require(bytes(addressETH).length > 0, "ETH address must be provided.");
        userProfile[msg.sender].addressETH = addressETH;
    }

    // Specify new handle for user
    function setUserHandle(string memory handle) external {
        require(bytes(handle).length > 0, "Handle must be provided.");
        userProfile[msg.sender].userHandle = handle;
    }

    // Specify new profile metadata IPFS hash for user
    function setUserMetadata(string memory metadataIPFSHash) external {
        require(bytes(metadataIPFSHash).length > 0, "Metadata IPFS hash must be provided.");
        userProfile[msg.sender].metadataIPFSHash = metadataIPFSHash;
    }

    /************
    Minting
    ************/


    // Mint a new token with a specific metadata hash location
    function mint(string memory metadataIPFSHash, string memory postURL, address creatorAddress) external {
        require(bytes(metadataIPFSHash).length > 0, "Metadata IPFS hash cannot be empty.");
        require(metadataTokenId[metadataIPFSHash] == 0, "That metadata IPFS hash has already been referenced.");
        require(postStatus[postURL] == false, "This post already minted");

        postStatus[postURL] = true;
        MOON.transferFrom(msg.sender, address(0xdead), mintPrice);

        uint256 tokenId = totalSupply() + 1; // Start at 1
        _safeMint(msg.sender, tokenId);
        _tokenSupply.increment();
        // track metadata IPFS hashes to be unique to each token ID
        metadataTokenId[metadataIPFSHash] = tokenId;
        // publisher details - track posts published for minter
        userProfile[msg.sender].postsPublished.push(tokenId);
        // creator details - track posts created for postr
        userProfile[creatorAddress].postsCreated.push(tokenId);
        // track Post details per token ID
        tokenPost[tokenId] = Post({
          publisherAddress: msg.sender,
          creatorAddress: creatorAddress,
          metadataIPFSHash: metadataIPFSHash,
          publisherTipsETH: 0,
          creatorTipsETH: 0,
          publisherTipsMOON: 0,
          creatorTipsMOON: 0
        });
    }

    /************
    Tipping
    ************/

    // Tip a token and it's creator with ETH
    function tipETH(uint256 tokenId) external payable {
        require(tokenId <= totalSupply(), "Cannot tip non-existent token.");
        uint256 amount = msg.value;
        // Calculate tip amounts based upon stored cut percentages
        uint256 hundo = 100;
        uint256 publisherTipAmount = amount.div(hundo.div(publisherTipCutPercent));
        uint256 creatorTipAmount = amount.sub(publisherTipAmount);
        // Send transactions
        payable(address(tokenPost[tokenId].creatorAddress)).transfer(creatorTipAmount);
        payable(address(tokenPost[tokenId].publisherAddress)).transfer(publisherTipAmount);
        // Store tip amounts for sender and recipients to the chain
        userProfile[msg.sender].tippedETH = userProfile[msg.sender].tippedETH.add(amount);
        tokenPost[tokenId].creatorTipsETH = tokenPost[tokenId].creatorTipsETH.add(creatorTipAmount);
        tokenPost[tokenId].publisherTipsETH = tokenPost[tokenId].publisherTipsETH.add(publisherTipAmount);
    }

    // Tip a token and it's creator with MOON
    function tipMOON(uint256 tokenId, uint256 amount) external {
        require(tokenId <= totalSupply(), "Cannot tip non-existent token.");
        // Ensure proper allowance for contract to send MOON on user behalf
        uint256 allowance = MOON.allowance(msg.sender, address(this));
        require(allowance >= amount, "MOON token allowance not high enough, must approve additional token transfers first.");
        // Calculate tip amounts based upon stored cut percentages
        uint256 hundo = 100;
        uint256 publisherTipAmount = amount.div(hundo.div(publisherTipCutPercent));
        uint256 creatorTipAmount = amount.sub(publisherTipAmount);
        // Send transactions
        MOON.transferFrom(msg.sender, address(tokenPost[tokenId].creatorAddress), creatorTipAmount);
        MOON.transferFrom(msg.sender, address(tokenPost[tokenId].publisherAddress), publisherTipAmount);
        // Store tip amounts for sender and recipients to the chain
        userProfile[msg.sender].tippedMOON = userProfile[msg.sender].tippedMOON.add(amount);
        tokenPost[tokenId].creatorTipsMOON = tokenPost[tokenId].creatorTipsMOON.add(creatorTipAmount);
        tokenPost[tokenId].publisherTipsMOON = tokenPost[tokenId].publisherTipsMOON.add(publisherTipAmount);
    }

    /************
    Overrides
    ************/

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        // Each token should return a unique IPFS hash
        return string(abi.encodePacked("ipfs://", tokenPost[tokenId].metadataIPFSHash));
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        // Prevent burning
    }
}

interface ERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
