// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/// @title MoNA Proxy Owner
/// @notice Manage NFT owner listings.
contract ProxyOwner is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event Executed(uint256 indexed action_id);
    event NFTListed(address sender, address nftContract, uint256 tokenId);
    event Received(address, uint);
    event TransferredToOwner(
        address _from,
        address _to,
        address _asset,
        uint256 _amount
    );
    event TransferredToCommunity(
        address _from,
        address _to,
        address _asset,
        uint256 _amount
    );

    address private _communityPool;

    /// @dev This is an easy way to create proposals for most actions.
    mapping(address => bytes) last_calldata;
    mapping(uint256 => action) actions;
    uint256 _last_action_id;
    /// @dev Maximum time between proposal time and trigger time.
    uint256 _expiration;

    /// @dev This is 100% scaled up by a factor of 10 to give us an extra 1 decimal place of precision
    uint256 public constant MAX_AMOUNT_SCALE = 1000;
    uint256 public constant MIN_AMOUNT_SCALE = 1;
    /// @dev i.e. 1% is 10 _communityFeeScaled, 0.1% is 1 _communityFeeScaled
    uint256 private _communityFeeScaled;

    struct action {
        address target;
        bytes callData;
        uint256 value;
        uint256 expiration; // Last timestamp this action can execute
        bool executed; // Was this action successfully executed
    }

    /// @dev Constructor of the Proxy Owner.
    /// @param _owner_ is the NFT owner.
    /// @param _pool_ is the MoNA community pool address.
    /// @param _communityFee_ is the fee that the community will get from the NFT sells.
    /// @param _expirationTime_ is the expiration time of the NFT sell.
    constructor(
        address _owner_,
        address _pool_,
        uint256 _communityFee_,
        uint256 _expirationTime_
    ) {
        _communityFeeScaled = _communityFee_;
        _communityPool = _pool_;
        _expiration = _expirationTime_;
        transferOwnership(_owner_);
    }

    /// @dev Method to send the NFT to the proxy.
    /// @param _nftContract is the NFT mother contract.
    /// @param _tokenId is the id of the specific NFT to be listed.
    function listNFT(address _nftContract, uint256 _tokenId) public {
        IERC721(_nftContract).transferFrom(msg.sender, address(this), _tokenId);
        emit NFTListed(msg.sender, _nftContract, _tokenId);
    }

    /// @dev Method to collect the amount resulting from the NFT sells.
    /// @param _asset is the type of asset to retrieve (can be ETH or ERC20s).
    function withdraw(address _asset) public {
        uint256 ownerAmount;
        uint256 communityAmount;
        address owner = Ownable.owner();
        if (_asset != address(0)) {
            uint256 totalAmount = IERC20(_asset).balanceOf(address(this));
            require(totalAmount > 0, "amount to withdraw is equal to zero");
            ownerAmount = totalAmount.mul(MAX_AMOUNT_SCALE).div(
                _communityFeeScaled + MAX_AMOUNT_SCALE
            );
            communityAmount = totalAmount.sub(ownerAmount);
            IERC20(_asset).safeTransferFrom(address(this), owner, ownerAmount);
            IERC20(_asset).safeTransferFrom(
                address(this),
                _communityPool,
                communityAmount
            );
        } else {
            uint256 totalAmount = address(this).balance;
            require(totalAmount > 0, "amount to withdraw is equal to zero");
            ownerAmount = totalAmount.mul(MAX_AMOUNT_SCALE).div(
                _communityFeeScaled + MAX_AMOUNT_SCALE
            );
            communityAmount = totalAmount.sub(ownerAmount);
            payable(owner).transfer(ownerAmount);
            payable(_communityPool).transfer(communityAmount);
        }
        emit TransferredToOwner(address(this), owner, _asset, ownerAmount);
        emit TransferredToCommunity(
            address(this),
            _communityPool,
            _asset,
            communityAmount
        );
    }

    /// @dev Method to execute an action using the callData from this sender's last call.
    /// @param _target is the target address for the execution.
    /// @param _value is the amount of ETH that will be in msg.value.
    function executeLast(address _target, uint256 _value) external {
        return execute(_target, last_calldata[msg.sender], _value);
    }

    /// @dev Method to execute an action.
    /// @param _target is the target address for the execution.
    /// @param _calldata is the raw input of the transaction to be executed.
    /// @param _value is the amount of ETH that will be in msg.value.
    function execute(
        address _target,
        bytes memory _calldata,
        uint256 _value
    ) public onlyOwner {
        action memory a;
        a.target = _target;
        a.callData = _calldata;
        a.value = _value;
        a.expiration = block.timestamp + _expiration;
        // Increment first because, 0 is not a valid ID.
        _last_action_id++;
        actions[_last_action_id] = a;
        require(
            block.timestamp < a.expiration,
            "action expiration time passed"
        );
        require(!a.executed, "action already executed");
        require(address(this).balance >= a.value, "action value incorrect");
        a.executed = true;
        a.target.call{value: a.value}(a.callData);
        //exec(a.target, a.callData, a.value);
        emit Executed(_last_action_id);
    }

    /// @dev Standard fallback method.
    fallback() external payable {
        last_calldata[msg.sender] = msg.data;
    }

    /// @dev Standard receive method.
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
}
