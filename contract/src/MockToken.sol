// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts@5.1.0/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    uint8 private _decimals;

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) ERC20(name_, symbol_) {
        _decimals = decimals_;
    }

    function mint(address to, uint256 value) external {
        _mint(to, value);
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }
}
