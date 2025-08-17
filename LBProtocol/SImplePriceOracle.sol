// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IPriceOracle.sol";
import "./ICToken.sol";
import "./ErrorReporter.sol";

contract SimplePriceOracle is PriceOracle, ErrorReporter, OwnableUpgradeable {
    mapping(address => uint) public prices;

    function initialize() public initializer {
        __Ownable_init();
    }

    function getUnderlyingPrice(CToken cToken) external view returns (uint) {
        uint price = prices[address(cToken)];
        if (price == 0) revert PriceError();
        return price;
    }

    function setUnderlyingPrice(CToken cToken, uint price) external onlyOwner {
        prices[address(cToken)] = price;
    }
}