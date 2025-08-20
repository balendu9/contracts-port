// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "./FlashLoanProvider.sol";

contract ArbitrageContract is IFlashLoanReceiver {
    using SafeERC20 for IERC20;

    address public immutable owner;
    address public immutable flashLoanProvider;
    address public immutable tokenA;
    address public immutable tokenB;
    address public immutable dex1Router; // DEX1 Router
    address public immutable dex2Router; // DEX2 Router

    event ArbitrageExecuted(uint256 borrowed, uint256 profit, uint256 gasUsed);

    constructor(
        address _flashLoanProvider,
        address _tokenA,
        address _tokenB,
        address _dex1Router,
        address _dex2Router
    ) {
        owner = msg.sender;
        flashLoanProvider = _flashLoanProvider;
        tokenA = _tokenA;
        tokenB = _tokenB;
        dex1Router = _dex1Router;
        dex2Router = _dex2Router;
    }

    // Trigger arbitrage
    function startArbitrage(uint256 amount, uint256 minProfit) external {
        require(msg.sender == owner, "Only owner");
        bytes memory params = abi.encode(minProfit);
        FlashLoanProvider(flashLoanProvider).flashLoan(amount, params);
    }

    // Flash loan callback (gas-optimized: minimal operations)
    function executeOperation(
        address token,
        uint256 amount,
        uint256 fee,
        address initiator,
        bytes calldata params
    ) external override returns (bool) {
        require(msg.sender == flashLoanProvider, "Invalid caller");
        require(token == tokenA, "Invalid token");

        uint256 minProfit = abi.decode(params, (uint256));
        uint256 balanceBefore = IERC20(tokenA).balanceOf(address(this));

        // Trade: TokenA -> TokenB on DEX1 (assume DEX1 has lower price for B)
        address[] memory path1 = new address[](2);
        path1[0] = tokenA;
        path1[1] = tokenB;
        IERC20(tokenA).safeApprove(dex1Router, amount);
        uint256[] memory amountsOut1 = IUniswapV2Router02(dex1Router).swapExactTokensForTokens(
            amount,
            0, // No min out for sim, but in prod add slippage check
            path1,
            address(this),
            block.timestamp
        );

        // Trade: TokenB -> TokenA on DEX2
        uint256 tokenBAmount = amountsOut1[1];
        address[] memory path2 = new address[](2);
        path2[0] = tokenB;
        path2[1] = tokenA;
        IERC20(tokenB).safeApprove(dex2Router, tokenBAmount);
        uint256[] memory amountsOut2 = IUniswapV2Router02(dex2Router).swapExactTokensForTokens(
            tokenBAmount,
            0,
            path2,
            address(this),
            block.timestamp
        );

        uint256 repaidAmount = amount + fee;
        uint256 balanceAfter = amountsOut2[1];
        require(balanceAfter >= repaidAmount + minProfit, "Insufficient profit");

        // Repay loan
        IERC20(tokenA).safeTransfer(flashLoanProvider, repaidAmount);

        // Emit event for logging
        uint256 profit = balanceAfter - repaidAmount;
        emit ArbitrageExecuted(amount, profit, gasleft());

        return true;
    }

    // Withdraw profits
    function withdraw() external {
        require(msg.sender == owner, "Only owner");
        IERC20(tokenA).safeTransfer(owner, IERC20(tokenA).balanceOf(address(this)));
    }
}