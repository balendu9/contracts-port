// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TokenA is ERC20 {
    constructor() ERC20("Token A", "TOKA") {
        _mint(msg.sender, 1_000_000 * 10**18); // Mint 1M tokens
    }
}