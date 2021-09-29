// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

contract ERC20MockUSD is ERC20PresetMinterPauser {
  constructor()
    ERC20PresetMinterPauser ("USD Mock Stablecoin", "USDMS")
    {}

  function decimals() override public view returns (uint8) {
    return 6;
  }
}
