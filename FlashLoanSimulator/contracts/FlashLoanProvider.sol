// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IFlashLoanReceiver {
    function executeOperation(address token, uint256 amount, uint256 fee, address initiator, bytes calldata params) external returns (bool);
}

contract FlashLoanProvider {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    uint256 public constant FEE = 9; // 0.09% fee (9 basis points)
    uint256 public constant FEE_DENOMINATOR = 10000;

    constructor(address _token) {
        token = IERC20(_token);
    }

    function flashLoan(uint256 amount, bytes calldata params) external {
        uint256 balanceBefore = token.balanceOf(address(this));
        uint256 fee = (amount * FEE) / FEE_DENOMINATOR;
        token.safeTransfer(msg.sender, amount);

        require(IFlashLoanReceiver(msg.sender).executeOperation(address(token), amount, fee, msg.sender, params), "Flash loan failed");

        uint256 balanceAfter = token.balanceOf(address(this));
        require(balanceAfter >= balanceBefore + fee, "Loan not repaid");
    }
}