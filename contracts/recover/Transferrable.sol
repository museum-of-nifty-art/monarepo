// SPDX-License-Identifier: GPLv3

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title SafeTransfer, allowing contract to withdraw tokens accidentally sent to itself
contract Transferrable {
    using Address for address payable;
    using SafeERC20 for IERC20;

    /// @dev This function is used to move tokens sent accidentally to this contract method.
    /// @dev The owner can chose the new destination address
    /// @param _to is the recipient's address.
    /// @param _asset is the address of an ERC20 token or 0x0 for ether.
    /// @param _amount is the amount to be transferred in base units.
    function _safeTransfer(
        address payable _to,
        address _asset,
        uint256 _amount
    ) internal {
        // address(0) is used to denote ETH
        if (_asset == address(0)) {
            _to.sendValue(_amount);
        } else {
            IERC20(_asset).safeTransfer(_to, _amount);
        }
    }
}
