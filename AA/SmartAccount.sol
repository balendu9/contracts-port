// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";

contract SmartAccount is IERC1271 {
    address public owner;
    address public entryPoint;
    uint256 public nonce;

    constructor(address _owner, address _entryPoint) {
        owner = _owner;
        entryPoint = _entryPoint;
    }

    modifier onlyEntryPoint() {
        require(msg.sender == entryPoint, "Only EntryPoint can call");
        _;
    }

    function validateUserOp(
        bytes calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external onlyEntryPoint returns (uint256 validationData) {
        if (missingAccountFunds > 0) {
            (bool success, ) = payable(msg.sender).call{value: missingAccountFunds}("");
            require(success, "Funding failed");
        }
        nonce++;
        return _validateSignature(userOp, userOpHash);
    }

    function _validateSignature(bytes calldata userOp, bytes32 userOpHash) internal view returns (uint256) {
        bytes memory signature = userOp[signatureOffset(userOp) :];
        address signer = ECDSA.recover(userOpHash, signature);
        return signer == owner ? 0 : 1;
    }

    function execute(address dest, uint256 value, bytes calldata data) external onlyEntryPoint {
        (bool success, ) = dest.call{value: value}(data);
        require(success, "Execution failed");
    }

    function isValidSignature(bytes32 hash, bytes memory signature) public view override returns (bytes4) {
        address signer = ECDSA.recover(hash, signature);
        return signer == owner ? this.isValidSignature.selector : bytes4(0);
    }

    function signatureOffset(bytes calldata userOp) internal pure returns (uint256) {
        return 20 + 32 + 32 + 32 + 32 + 32 + 32 + 32 + 32; // Based on UserOperation structure
    }

    receive() external payable {}
}