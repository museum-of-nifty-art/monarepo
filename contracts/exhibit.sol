// SPDX-License-Identifier: UNLICENSED
// Denis Milicevic
// All Rights Reserved

// TODO rename to Exhibit.sol

pragma solidity >=0.8.0;
/*
The new ABI coder (v2) is able to encode and decode arbitrarily nested arrays and structs. It might produce less optimal code and has not received as much testing as the old encoder, but is considered non-experimental as of Solidity 0.6.0. You still have to explicitly activate it using pragma abicoder v2;. Since it will be activated by default starting from Solidity 0.8.0, there is the option to select the old coder using pragma abicoder v1;.
*/
pragma abicoder v1;
//pragma experimental SMTChecker;

// 
// pragma solidity ^0.8.0;
// 
// import "./SafeERC20.sol";
// 
// // could use this and be safe/deploy each time, but this would make a bonding tx cost at least 60k gas off the bat.
// 
// /**
//  * @dev A token holder contract that will allow a beneficiary to extract the
//  * tokens after a given release time.
//  *
//  * Useful for simple vesting schedules like "advisors get all of their tokens
//  * after 1 year".
//  */
// contract TokenTimelock {
//     using SafeERC20 for IERC20;
// 
//     // ERC20 basic token contract being held
//     IERC20 private immutable _token;
// 
//     // beneficiary of tokens after they are released
//     address private immutable _beneficiary;
// 
//     // timestamp when token release is enabled
//     uint256 private immutable _releaseTime;
// 
//     constructor(
//         IERC20 token_,
//         address beneficiary_,
//         uint256 releaseTime_
//     ) {
//         require(releaseTime_ > block.timestamp, "TokenTimelock: release time is before current time");
//         _token = token_;
//         _beneficiary = beneficiary_;
//         _releaseTime = releaseTime_;
//     }
// 
//     /**
//      * @return the token being held.
//      */
//     function token() public view virtual returns (IERC20) {
//         return _token;
//     }
// 
//     /**
//      * @return the beneficiary of the tokens.
//      */
//     function beneficiary() public view virtual returns (address) {
//         return _beneficiary;
//     }
// 
//     /**
//      * @return the time when the tokens are released.
//      */
//     function releaseTime() public view virtual returns (uint256) {
//         return _releaseTime;
//     }
// 
//     /**
//      * @notice Transfers tokens held by timelock to beneficiary.
//      */
//     function release() public virtual {
//         require(block.timestamp >= releaseTime(), "TokenTimelock: current time is before release time");
// 
//         uint256 amount = token().balanceOf(address(this));
//         require(amount > 0, "TokenTimelock: no tokens to release");
// 
//         token().safeTransfer(beneficiary(), amount);
//     }
// }

/**
 * @title ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
interface IERC20 {
  function totalSupply() external view returns (uint256);

  function balanceOf(address who) external view returns (uint256);

  function allowance(address owner, address spender)
    external view returns (uint256);

  function transfer(address to, uint256 value) external returns (bool);

  function approve(address spender, uint256 value)
    external returns (bool);

  function transferFrom(address from, address to, uint256 value)
    external returns (bool);

  event Transfer(
    address indexed from,
    address indexed to,
    uint256 value
  );

  event Approval(
    address indexed owner,
    address indexed spender,
    uint256 value
  );
}

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}


/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

// use ERC165 to identify supported interfaces in a parent contract
interface ERC165 {
    /// @notice Query if a contract implements an interface
    /// @param interfaceID The interface identifier, as specified in ERC-165
    /// @dev Interface identification is specified in ERC-165. This function
    ///  uses less than 30,000 gas.
    /// @return `true` if the contract implements `interfaceID` and
    ///  `interfaceID` is not 0xffffffff, `false` otherwise
    function supportsInterface(bytes4 interfaceID) external view returns (bool);
}

/// @title ERC-721 Non-Fungible Token Standard
/// @dev See https://github.com/ethereum/EIPs/blob/master/EIPS/eip-721.md
///  Note: the ERC-165 identifier for this interface is 0x80ac58cd
interface IERC721 /* is ERC165 */ {
    /// @notice Find the owner of an NFT
    /// @dev NFTs assigned to zero address are considered invalid, and queries
    ///  about them do throw.
    /// @param _tokenId The identifier for an NFT
    /// @return The address of the owner of the NFT
    function ownerOf(uint256 _tokenId) external view returns (address);
}

contract NiftyExhibitForERC721 {
    using SafeERC20 for IERC20;
    struct ListedNFT_old {
        address owner;
        uint64 duration; // 64-bits of seconds gives us 584.9 billion years to work with, and packs
        bytes32 listID; // keccak hash of the NFT address + id concat
        // could also skip making this whole struct, and instead just have a mapping consisting of the 
        // listID, which is enumerated with the owner address, duration, and NFT deets, and put out with a
        // event
    }

    // mapping notes when the NFT expires
    // we get owner from the underlying contract
    mapping(bytes32=>uint256) listedNFT;
    mapping(bytes32=>bytes32) efficientListedNFTStruct; // a way to enumerate a mapping to a struct efficiently, by storing the key as a hash, and struct values as accompanying hash
    // currently based for erc721
    // not checking for fees yet
    // consider a batched metthod

    event ListingNFT(
        bytes32 indexed id,
        address indexed owner,
        address indexed addressNFT,
        uint256 indexed idNFT,
        uint64 duration,
        uint256 expiryTime // would need to be epoch-based to be useful as index, for lower granularity
    ) anonymous;

    // NOTE 
    // consider building everything out with non-standard packed mode in mind: 
    // https://docs.soliditylang.org/en/v0.8.7/abi-spec.html#non-standard-packed-mode
    // using abi.encodePacked to call.

    // consider adding a maximum sane duration max... for reasons of front-end event fetching efficacy
    // so we don't have to look back thousands of blocks for active NFTs listings.
    // could also be rectified with a listing in storage?
    // consider listingEpochs instead, which would allow us to take advantage of: 
    // topics - Array: An array of values which must each appear in the log entries. The order is important, if you want to leave topics out use null, e.g. [null, '0x12...']. You can also pass an array for each topic with options for that topic e.g. [null, ['option1', 'option2']]
    //
    // could make alternative function that accepts uint256 expiry time
    function listNFT(address _contractAddressNFT, uint256 _tokenIdNFT, uint64 _duration)
    external {
        // check the owner??, maybe not needed her? could allow for more users.
        // this is the most ERC721 specific part... could delegate this to a upgradeable contract, that handles
        // ERC721 + is made modular to support cryptopunks and others, erc1135...
        // could also just handle this using abiEncodes, or whitelist them in this contract...
        // could also always do this first, and if it fails/is missing this interface allow a fallback
        require(IERC721(_contractAddressNFT).ownerOf(_tokenIdNFT) == msg.sender);
        require(_duration > 86400); // make sure minimum duration of 1 day is met... consider settable gov param
        require(_duration <= 86400*30); // max enforcement, for more efficient event scanning, TODO make settable

        bytes32 id = getCurationId(_contractAddressNFT, _tokenIdNFT);
        // TODO is optimizer smart enough to automate storing repeated storage calls intrafunction, so this isn't needed?
        require(listedNFT[id] <= block.timestamp);

        // no need to store dup timestamp call, its opcode is only 2 gas
        uint256 expiry = block.timestamp + _duration;

        // by emitting duration, we offload the possibility of figuring out listing time off-chain
        emit ListingNFT(id, msg.sender, _contractAddressNFT, _tokenIdNFT, _duration, expiry);

        listedNFT[id] = expiry;
    }

    // helpers
    function getCurationId(address _contractNFT, uint256 _tokenIdNFT)
    public
    view
    returns (bytes32 id) {
        return keccak256(abi.encodePacked(msg.sender, _contractNFT, _tokenIdNFT));
    }

    function getId(address _owner, address _contractNFT, uint256 _tokenIdNFT, uint64 _duration)
    public
    pure
    returns (bytes32 id) {
        return keccak256(abi.encodePacked(_owner, _contractNFT, _tokenIdNFT, _duration));
    }

    //mapping (bytes32=>bytes32)
    struct Bonded {
        bool claimed; //first slot start
        uint64 expiry;
        address ERC20; // first slot end
        uint256 amount; // second slot
    }

    mapping (address => mapping(uint256 => Bonded)) bondTracker;
    // for efficiency, but sacrificing UX, could have a variable tracking the last unclaimed idx,
    // the pitfall with that is that earlier expiring bonds cannot be claimed until some later ones expire
    // could work around this by using a simple sort algorithm, before the push, where we check if this new bonding
    // expires before or after the last element, and depending on that, we shift it in or not.
    mapping (address => Bonded[]) bondTracker2;
    // could track via events?
    mapping (address => uint256) bondIdxCtr; 
    // check whitelisted ERC20s

    // TODO can be made more efficient by iterating off-chain or with a helper function that iterates, is viewed, and returns array of claimable idxes
    // so we technically don't need to emit idx, and can consider array deletion even,,,
    // TODO consider one where multiple withdraws are possibru
    event LOG_Bonded(
        bytes32 indexed curationId,
        address indexed reacter,
        address indexed token,
        uint256 amount,
        uint64 expiry,
        uint256 points,
        uint256 bondTrackerIdx
    );

    mapping (address => bool) whitelistedERC20; 

    function withdrawExpiredBond(uint256 _idx) 
    external {
        Bonded memory bond = bondTracker2[msg.sender][_idx];
        require(bond.claimed == false);
        require(bond.expiry < block.timestamp);

        // TODO consider deletion for pub wellbeing and avoid storj rent
        bondTracker2[msg.sender][_idx].claimed = true;

        IERC20(bond.ERC20).safeTransfer(
            msg.sender,
            bond.amount
        );
    }
    function reactionBond(bytes32 _curationId, address _ERC20, uint256 _amount, uint64 _duration)
    external {
        // we don't use a variable here for optimization (optimizer is smart enough to optimize, with sufficiently high runs)
        // we use the var here as a means of a common access point, i.e. if we wish to read another storj var we change it here,
        // instead of multiple times in the code
        uint64 curationExpiryTime = uint64(listedNFT[_curationId]);
        require(curationExpiryTime > block.timestamp);

        // TODO check that user hasn't already bonded on this NFT or come up with mechanism that doesn't allow
        // them to circumvent quadratic scoring

        // get tokens relative WETH value from an oracle (basically WETH will be 1 automagically)
        // we could also control these vars ourselves
        // calc points
        // NOTE naively assumes just USDT stablecoin atm, for other ERC20 we will need to calc TWAP TODO
        // set min point threshold here
        uint points = quadraticScoring(getDollarValue(_ERC20, _amount), _duration);
        // TODO check if any diff between > or >= in terms of gas costs
        // NOTE consider some sane settable minimum
        require(points > 0);

        // TODO ensure ERC20 is whitelisted
        IERC20(_ERC20).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );

        // bonding time cannot exceed curation expiry time, so if it would yield higher bond time
        // we fallback and set the bonding expiry time to match the curation expiry
        uint64 bondingExpiryTime = _duration + block.timestamp <= curationExpiryTime ?
            _duration + uint64(block.timestamp) :
            curationExpiryTime - uint64(block.timestamp);

        //bondTracker[msg.sender][bondIdxCtr[msg.sender]++] = Bonded(false, bondingExpiryTime, _ERC20, _amount);
        // TODO consider sorting technique for claim tracking
        // TODO need to fix this mechanism so it tracks repeated rebondings OR block this msg.sender from doing anymore bondings this epoch
        uint bondTrackerIdx = bondTracker2[msg.sender].length;
        bondTracker2[msg.sender].push(Bonded(false, bondingExpiryTime, _ERC20, _amount));
        emit LOG_Bonded(_curationId, msg.sender, _ERC20, _amount, bondingExpiryTime, points, bondTrackerIdx);



        
        // send points
        // curationID add points
        // bonder add points
        // TODO the above are not strictly necessary for V0, but will be for future versions



    }

   function quadraticScoring(uint _dollarValue, uint64 _duration) 
   public
   pure returns (uint) {
       // TODO apply bonus somehow on early finding if possibru?
       // TODO levels
       // sqrt(200) * 86400 * 30 *20  / 1e6 needs to be improved, puts a bit too much power in the crowd, i.e. not very sybil resistant
       return sqrt(_dollarValue) * _duration;
   }

    // consider whether ETH value may be better? It would grow with the system maybeh?
   function getDollarValue(address _ERC20, uint _amount)
   public
   view
   returns (uint) {
       // this currently only works with USD stablecoins
       return _amount / 10** IERC20Metadata(_ERC20).decimals();
   }

    // from uniswap v2
    // TODO consider other more efficient but also tried and true: https://github.com/hifi-finance/prb-math
    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    // helpers to build needed approve call data on erc20, can be offloaded to just ui as well
    function getApproveTokenCalldata() 
    external
    view
    returns (bytes memory data) {
        data = abi.encodeWithSelector(
            IERC20(address(0)).approve.selector,
            address(this),
            type(uint256).max
        );
    }

    // NOTE consider setting to 1, instead of 0, as i believe we no longer get storage refunds, or at least are slated not to
    // so keeping this non-zero would at least avoid future re-approval cost increases, where setting back from zero to non-zero is 20k gas
    function getUnapproveTokenCalldata() 
    external
    view
    returns (bytes memory data) {
        data = abi.encodeWithSelector(
            IERC20(address(0)).approve.selector,
            address(this),
            0
        );
    }
}
