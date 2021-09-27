// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

/**
 * @dev This is specified here as we don't rely on nested structs/array or dynamic bytes
 * and v1 is still apparently better tested. Would be useful to explore any noted differences
 * and maybe confirm with the solc guys.
 */
pragma abicoder v1; // solhint-disable-line compiler-version

/**
 * @dev This should be enabled upon prod compilation
 * check if the SMTChecker can be enabled via CLI, maybe under model-checker
 */
// pragma experimental SMTChecker;

/**
 * @dev Imports necessary interfaces
 */
import "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import "@openzeppelin/contracts/interfaces/IERC721.sol";
/**
 * @dev Unused interface atm, but consider if this can have some use
 */
import "@openzeppelin/contracts/interfaces/IERC165.sol";

/**
 * @dev Inherit safe ERC20 methods
 */
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @author Denis Milicevic
 *
 * @notice A contract allowing ERC721 owners to list their NFTs for specified durations
 * while users can bond ERC20 tokens as a form of feedback, utilizing quadratic scoring techniques based on value
 * and duration of the bond.
 *
 * @dev Tailored to ERC721, explore avenues to make this more flexible and especially for non-standard cryptopunks
 *
 * @custom:notes
 *
 *
 * @custom:legal All Rights Reserved
 */
contract Exhibit {
    using SafeERC20 for IERC20;

    /**
     * @dev Tracks if an NFT is actively listed.
     * Key is the curation id
     * Value is the expiry, zero means it hasn't been listed before and non-zero indicates it's active or expired
     */
    mapping(bytes32 => uint256) listedNFT;

    /**
     * @notice Event that is emitted upon a successful NFT listing by its respective owner.
     *
     * @dev Set as an anonymous event so we can index by 4 of its params instead of 3 + its topic.
     * Consider changing this after UI integration, the topic may turn out more useful, as we can derive
     * the id from the NFT address + id. In fact, idNFT may be the useless param here, as we'll always
     * want the addressNFT with it, and if we have both, we may as well just go with the curation id.
     *
     * @param id The curation
     */
    event ListingNFT(
        bytes32 indexed id,
        address indexed owner,
        address indexed addressNFT,
        uint256 indexed idNFT,
        uint64 duration,
        uint256 expiryTime
    ) anonymous;

    /**
     * @notice Allows collectors/artists to list their NFTs if duration requirements are met and fees paid
     *
     * @dev Does sanity checks including ensuring the lister in fact is the owner of the NFT
     * A minimum duration is enforced
     * A maximum duration is enforced
     * An id is derived from the NFT owner, contract address and associated NFT id
     * Ensures the NFT has not been listed, or isn't active by checking its expiry being zero/non-zero but past now
     * The expiry for this NFT is calculated by summing the current block timestamp and duration parameter
     * The ListingNFT event is emitted
     * The NFT is stored with the updated expiry to denote it is active
     *
     * Currently foregoes the fee collection
     * Consider alternative func that allows for specific expiration time to be set after risk-assessment
     * Consider batching func
     * Consider epochs as an improved mechanism to find active listings
     * Consider the possibility of allowing non-owners to list under alternative arrangement?
     *
     * @param _contractAddressNFT The origin contract address of the NFT
     * @param _tokenIdNFT The associated token id of the NFT on that contract
     * @param _duration The amount of time in seconds the listing should be active till from now
     *
     * @custom:note This is the only function well commented, to serve as an example basis on good format
     * the rest of this code should follow, but left out for now, to allow for more code fluidity/dev
     */
    function listNFT(address _contractAddressNFT, uint256 _tokenIdNFT, uint64 _duration)
    external {
        // this is the most ERC721 specific part... could delegate this to a upgradeable contract, that handles
        // ERC721 + is made modular to support cryptopunks and others, erc1135...
        // could also just handle this using abiEncodes, or whitelist them in this contract...
        // could also always do this first, and if it fails/is missing this interface allow a fallback
        require(IERC721(_contractAddressNFT).ownerOf(_tokenIdNFT) == msg.sender);
        // duration sanity checks, currently enabled for UI efficacy
        require(_duration > 86400); // make sure minimum duration of 1 day is met... consider settable gov param
        require(_duration <= 86400*30); // max enforcement, for more efficient event scanning, TODO make settable

        bytes32 id = getCurationId(_contractAddressNFT, _tokenIdNFT);
        // TODO is optimizer smart enough to automate storing repeated storage calls inscope, so this isn't needed?
        require(listedNFT[id] <= block.timestamp);

        // no need to store dup timestamp call, its opcode is only 2 gas
        uint256 expiry = block.timestamp + _duration;

        // by emitting duration, we offload the possibility of figuring out listing time off-chain (exp - dur)
        emit ListingNFT(id, msg.sender, _contractAddressNFT, _tokenIdNFT, _duration, expiry);

        listedNFT[id] = expiry;
    }

    // helpers
    function getCurationId(address _contractNFT, uint256 _tokenIdNFT)
    public
    view
    returns (bytes32 id) {
        // TODO consider omitting msg.sender... so points can be cumulative across owners
        // as they ought to be OR see if this indeed the right mechanism to request
        // a points transfer, assuming sale happened via MONA
        return keccak256(abi.encodePacked(msg.sender, _contractNFT, _tokenIdNFT));
    }

    struct Bonded {
        bool claimed; //first slot start
        uint64 expiry; // u64 is sufficient for time, consider updating this errywhere
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

    // TODO can be made more efficient by iterating off-chain or with a helper function that iterates,
    // is viewed, and returns array of claimable idxes
    // so we technically don't need to emit idx, and can consider array deletion even,,,
    // TODO consider one where multiple withdraws are possibru
    // TODO decide on if we should prefix events with E_ Log or LOG_
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
        /**
         * we don't use a variable here for optimization
         * (optimizer is smart enough to optimize, with sufficiently high runs)
         * it is var'd for better code flexibility and editability, so we can just change it from here once
         * instead of multiple times throughout the code the code
         */
        uint64 curationExpiryTime = uint64(listedNFT[_curationId]);
        require(curationExpiryTime > block.timestamp);

        /**
         * TODO check that user hasn't already bonded on this NFT or come up with mechanism that doesn't allow
         * them to circumvent quadratic scoring

         * get tokens relative WETH value from an oracle (basically WETH will be 1 automagically)
         * we could also control these vars ourselves
         * calc points
         * NOTE naively assumes just USDT stablecoin atm, for other ERC20 we will need to calc TWAP TODO
         * set min point threshold here
         */
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
        // TODO need to fix this mechanism so it tracks repeated rebondings OR
        // block this msg.sender from doing anymore bondings this epoch
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
       // sqrt(200) * 86400 * 30 *20  / 1e6 needs to be improved,
       // puts a bit too much power in the crowd, i.e. not very sybil resistant
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

    // NOTE consider resetting approval to 1, instead of 0, as i believe we no
    // longer get storage refunds, or at least are slated not to
    // so keeping this non-zero would at least avoid future re-approval cost increases,
    // where setting back from zero to non-zero is 20k gas
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
