// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

interface IEntryPoint {
    function depositTo(address account) external payable;
}

contract Paymaster {
    address public owner;
    address public entryPoint;
    uint256 public constant DAILY_LIMIT = 5;
    uint256 public constant DAY_SECONDS = 86400;

    mapping(address => uint256) public opCount;
    mapping(address => uint256) public lastReset;

    constructor(address _owner, address _entryPoint) {
        owner = _owner;
        entryPoint = _entryPoint;
    }

    modifier onlyEntryPoint() {
        require(msg.sender == entryPoint, "Only EntryPoint can call");
        _;
    }

    function validatePaymasterUserOp(
        bytes calldata userOp,
        bytes32 userOpHash,
        uint256 maxCost
    ) external onlyEntryPoint returns (bytes memory context, uint256 validationData) {
        address sender = address(bytes20(userOp[0:20]));
        uint256 currentTime = block.timestamp;

        if (lastReset[sender] + DAY_SECONDS <= currentTime) {
            opCount[sender] = 0;
            lastReset[sender] = currentTime - (currentTime % DAY_SECONDS);
        }

        require(opCount[sender] < DAILY_LIMIT, "Daily limit exceeded");
        opCount[sender]++;

        return (abi.encode(sender), 0);
    }

    function postOp(
        bytes calldata context,
        uint256 actualGasCost
    ) external onlyEntryPoint {
        // No-op; gas already paid
    }

    function deposit() external payable {
        IEntryPoint(entryPoint).depositTo{value: msg.value}(address(this));
    }

    function withdraw(address payable to, uint256 amount) external {
        require(msg.sender == owner, "Only owner");
        (bool success, ) = to.call{value: amount}("");
        require(success, "Withdrawal failed");
    }

    receive() external payable {}
}