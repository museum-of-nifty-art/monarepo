// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract ProxyOwner is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address private _communityPool;

    // This is an easy way to create proposals for most actions.
    mapping(address => bytes) last_calldata;
    mapping(uint256 => action) actions;
    uint256 _last_action_id;
    // Maximum time between proposal time and trigger time.
    uint _expiration;

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

    event NFTListed(address sender, address nftContract, uint256 tokenId);
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
    event Executed(uint256 indexed action_id);

    constructor(
        address _owner_,
        address _pool_,
        uint256 _communityFee_,
        uint256 _expirationTime_
    ) public {
        _communityFeeScaled = _communityFee_;
        _communityPool = _pool_;
        _expiration = _expirationTime_;
        transferOwnership(_owner_);
    }

    function listNFT(address nftContract, uint256 tokenId) public {
        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);
        emit NFTListed(msg.sender, nftContract, tokenId);
    }

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

    // `execute` an action using the callData from this sender's last call.
    function executeLast(address target, uint256 value) external {
        return execute(target, last_calldata[msg.sender], value);
    }

    function execute(
        address target,
        bytes memory callData,
        uint256 value
    ) public onlyOwner {
        action memory a;
        a.target = target;
        a.callData = callData;
        a.value = value;
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

    fallback() external payable {
        last_calldata[msg.sender] = msg.data;
    }
}
