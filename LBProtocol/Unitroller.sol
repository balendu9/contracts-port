// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ErrorReporter.sol";

contract Unitroller is ErrorReporter {
    address public implementation;
    address public admin;

    event NewImplementation(address oldImplementation, address newImplementation);

    constructor() {
        admin = msg.sender;
    }

    fallback() external payable {
        (bool success, bytes memory returndata) = implementation.delegatecall(msg.data);
        assembly {
            if eq(success, 0) { revert(add(returndata, 0x20), mload(returndata)) }
            return(add(returndata, 0x20), mload(returndata))
        }
    }

    receive() external payable {}

    function _setImplementation(address newImplementation) public {
        if (msg.sender != admin) revert Unauthorized();
        address old = implementation;
        implementation = newImplementation;
        emit NewImplementation(old, newImplementation);
    }
}