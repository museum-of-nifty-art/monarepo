// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./recover/Transferrable.sol";

/// @title MoNA Marketplace
/// @notice Manage NFT marketplace listings.
contract Marketplace is ReentrancyGuard, Ownable, Transferrable {
    using Counters for Counters.Counter;
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    Counters.Counter private itemIds;
    Counters.Counter private itemSold;

    event Received(address, uint);
    event Claimed(address indexed _to, address indexed _asset, uint256 _amount);
    event MarketplaceTokenListed(
        uint256 indexed _marketItemId,
        address indexed _contractAddress,
        uint256 indexed _tokenId,
        address _seller,
        address _newOwner,
        uint256 _price
    );

    /// @dev This is the _poolAmountScaled by a factor of 10.
    uint256 private _poolAmountScaled;

    /// @dev This is 100% scaled up by a factor of 10 to give us an extra 1 decimal place of precision: 1% is 10.
    uint256 public constant MAX_AMOUNT_SCALE = 1000;
    uint256 public constant MIN_AMOUNT_SCALE = 1;

    /// @dev MoNA tresury.
    address payable private _treasury;
    /// @dev MoNA community pool.
    address payable private _pool;

    bool private _lockedTreasury;
    bool private _lockedPool;

    uint256 public listingFee = 0.01 ether;

    struct MarketNFT {
        uint256 id;
        address contractAddress;
        uint256 tokenId;
        string metadataUri;
        address payable seller;
        address payable owner; // Set to 0 when put to 0, new owner not known yet.
        uint256 price; // Defined by the seller.
    }

    mapping(uint256 => MarketNFT) marketBasket;

    /// @dev Initialize is the constructor in upgradaeble contracts.
    /// @param _listingFee is the Reaction$ fee for listing an asset.
    /// @param _poolPercentage_ is how much percentage goes to the pool scaled of a 10 factor.
    /// @param _treasury_ is the Reaction$ treasury address.
    /// @param _pool_ is the Reaction$ community pool address.
    function initialize(
        uint256 _listingFee,
        uint256 _poolPercentage_,
        address payable _treasury_,
        address payable _pool_
    ) public {
        listingFee = _listingFee;
        _poolAmountScaled = _poolPercentage_;
        _treasury = _treasury_;
        _pool = _pool_;
    }

    /// @notice Set the fee to pay to the platform for selling the nft.
    /// @param _newListingPrice is the price to pay for listing.
    function setListingPrice(uint256 _newListingPrice) external onlyOwner {
        listingFee = _newListingPrice;
    }

    // @notice List the NFT to the MoNA marketplace.
    // @param _contractAddress erc721 contract address.
    // @param _tokenId id of the erc721.
    // @param _metadataUri uri of the nft.
    // @param _price sale price set by the nft owner.
    function listNFTOnMarket(
        address _contractAddress,
        uint256 _tokenId,
        string memory _metadataUri,
        uint256 _price
    ) external payable nonReentrant {
        // TODO check if msg.sender is the owner of the nft
        require(_price > 0, "Price must be higher than 0");
        require(
            msg.value == listingFee,
            "Price must be equal to listing price"
        );
        // Increment the counter due to new item listed.
        itemIds.increment();
        // Get the latest id.
        uint256 marketItemId = itemIds.current();
        // Save the nft info into the market basket.
        marketBasket[marketItemId].id = marketItemId;
        marketBasket[marketItemId].contractAddress = _contractAddress;
        marketBasket[marketItemId].tokenId = _tokenId;
        marketBasket[marketItemId].seller = payable(msg.sender);
        marketBasket[marketItemId].owner = payable(address(0));
        marketBasket[marketItemId].price = _price;
        marketBasket[marketItemId].metadataUri = _metadataUri;
        // Approve the marketplace contract to transfer the nft.
        IERC721(_contractAddress).approve(address(this), _tokenId);
        emit MarketplaceTokenListed(
            marketItemId,
            _contractAddress,
            _tokenId,
            msg.sender,
            address(0),
            _price
        );
    }

    /// @notice get the owner of a listed nft on MoNA marketplace.
    /// @param _marketItemId id of the nft on MoNA marketplace.
    /// @return the owner of the market item.
    function getNFTOwner(uint256 _marketItemId) public view returns (address) {
        address contractAddress = marketBasket[_marketItemId].contractAddress;
        uint256 tokenId = marketBasket[_marketItemId].tokenId;
        // Get the NFT owner.
        return IERC721(contractAddress).ownerOf(tokenId);
    }

    /// @notice set new owner for a listed nft on MoNA marketplace that was sold on a secondary market.
    /// @param _marketItemId id of the nft on MoNA marketplace.
    function setNFTOwner(uint256 _marketItemId) external {
        address seller = marketBasket[_marketItemId].seller;
        address newOwner = getNFTOwner(_marketItemId);
        // Check if the seller is different than the owner, 
        //if they are different means the item was sold on another market.
        require(seller != newOwner, "Item still unsold");
        // Set the item as sold.
        marketBasket[_marketItemId].owner = payable(newOwner);
    }

    /// @notice check if the nft is listed in the market.
    /// @param _marketItemId id of the nft on MoNA marketplace.
    /// @return if the nft is listed or not.
    function isNFTListed(uint256 _marketItemId) public view returns (bool) {
        if (
            marketBasket[_marketItemId].seller != address(0) &&
            marketBasket[_marketItemId].owner == address(0)
        ) {
            return true;
        } else {
            return false;
        }
    }


    // @notice buyer performs the NFT sale.
    // @param _contractAddress ERC721 contract address.
    // @param _marketItemId id of the item in the marketplace.
    function executeNFTSale(address _contractAddress, uint256 _marketItemId)
        public
        payable
        nonReentrant
    {
        // Need to check the person is still NFT owner.
        address owner = getNFTOwner(_marketItemId);
        address payable seller = marketBasket[_marketItemId].seller;
        require(owner == address(0), "item sold on secondary market");
        // Get contract address as well.
        uint256 price = marketBasket[_marketItemId].price;
        uint256 tokenId = marketBasket[_marketItemId].tokenId;
        require(msg.value == price, "value sent does not match the nft price");
        seller.transfer(msg.value);
        // Send the nft to the buyer.
        IERC721(_contractAddress).transferFrom(
            address(this),
            msg.sender,
            tokenId
        );
        // Set buyer as owner.
        marketBasket[_marketItemId].owner = payable(msg.sender);
        // Increment the item sold counter.
        itemSold.increment();
        uint256 poolAmount = msg.value.mul(MAX_AMOUNT_SCALE).div(
            _poolAmountScaled + MAX_AMOUNT_SCALE
        );
        uint256 treasuryAmount = msg.value.sub(poolAmount);
        // Pay the percentage to the pool.
        _pool.transfer(poolAmount);
        _treasury.transfer(treasuryAmount);
        // Pay the listing price to the contract.
        payable(address(this)).transfer(listingFee);
    }

    /// @notice Retrieve the selected market item.
    /// @param _marketItemId is the id of the nft listed on the platform.
    /// @return items the struct representing the nft selected.
    function getMarketItem(uint256 _marketItemId)
        public
        view
        returns (MarketNFT memory)
    {
        MarketNFT storage currentItem = marketBasket[_marketItemId];
        return currentItem;
    }

    /// @notice Get all the nfts unsold on the market.
    /// @return items the whole NFTs struct of unsold nfts.
    function getUnsoldNFTsOnMarket()
        public
        view
        returns (MarketNFT[] memory items)
    {
        // Get the amount of nfts listed on the market.
        uint256 itemCount = itemIds.current();
        // Get the amount of unsold nfts on the market.
        uint256 unsoldItemCount = itemCount - itemSold.current();
        // Set the iterator to 0 for the unsold nft array.
        uint256 currentIdex = 0;
        // Create an array of the same size of unsold nfts.
        items = new MarketNFT[](unsoldItemCount);
        // Loop over all the sold and unsold the nfts.
        for (uint256 i = 0; i < itemCount; i++) {
            // if the nft is unsold.
            if (marketBasket[i + 1].owner == address(0)) {
                // Get the current unsold nft market id.
                uint256 currentId = marketBasket[i + 1].id;
                // Get the current nft.
                MarketNFT storage currentItem = marketBasket[currentId];
                // Save the unsold nft in the unsold nft array to return.
                items[currentIdex] = currentItem;
                // Increment the unsold nft index.
                currentIdex += 1;
            }
        }
        // Return unsold items.
        return items;
    }

    /// @notice get nfts bought by the sender.
    /// @return the whole NFTs struct of the caller.
    function fetchMyNFTs() public view returns (MarketNFT[] memory) {
        uint256 totalItemCount = itemIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (marketBasket[i + 1].owner == msg.sender) {
                itemCount += 1;
            }
        }
        MarketNFT[] memory items = new MarketNFT[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (marketBasket[i + 1].owner == msg.sender) {
                uint256 currentId = i + 1;
                MarketNFT storage currentItem = marketBasket[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    /// @dev Ether can be deposited from any source, so this contract should be payable by anyone.
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    /// @dev Withdraw tokens from the smart contract to the specified account.
    /// @param _to the receiver of the claim.
    /// @param _asset the token to be claimed.
    /// @param _amount the amount to be claimed.
    function claim(
        address payable _to,
        address _asset,
        uint256 _amount
    ) external onlyOwner {
        _safeTransfer(_to, _asset, _amount);
        emit Claimed(_to, _asset, _amount);
    }
}
