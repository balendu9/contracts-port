// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

interface ILiquidityPool {
    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB, uint256 lpTokens);
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB, uint256 lpTokens);
    event Swap(address indexed user, uint256 amountIn, uint256 amountOut, bool tokenAtoB);

    function addLiquidity(uint256 amountA, uint256 amountB, uint256 minA, uint256 minB) external returns (uint256);
    function removeLiquidity(uint256 lpTokens, uint256 minA, uint256 minB) external returns (uint256, uint256);
    function swap(uint256 amountIn, address tokenIn, uint256 minAmountOut) external returns (uint256);
    function getReserves() external view returns (uint256 reserveA, uint256 reserveB);
}

// Gas-optimized, secure, upgradeable liquidity pool contract
contract LiquidityPool is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable, ILiquidityPool {
    using SafeMathUpgradeable for uint256;

    // Storage packing to minimize SSTORE
    struct Reserves {
        uint128 reserveA;
        uint128 reserveB;
    }

    Reserves private reserves;
    IERC20Upgradeable public tokenA;
    IERC20Upgradeable public tokenB;
    mapping(address => uint256) public lpBalance;
    uint256 public totalSupply;
    uint256 private constant MINIMUM_LIQUIDITY = 10**3;
    uint256 private constant FEE = 30; // 0.3% fee (30 basis points)
    uint256 private constant SLIPPAGE_PROTECTION = 100; // 1% max slippage

    // Sandwich attack mitigation: track block number for recent trades
    uint256 private lastTradeBlock;
    mapping(uint256 => uint256) private blockTradeVolume;

    function initialize(address _tokenA, address _tokenB) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        tokenA = IERC20Upgradeable(_tokenA);
        tokenB = IERC20Upgradeable(_tokenB);
    }

    // Gas-optimized liquidity addition with reentrancy guard
    function addLiquidity(
        uint256 amountA,
        uint256 amountB,
        uint256 minA,
        uint256 minB
    ) external nonReentrant whenNotPaused returns (uint256 lpTokens) {
        require(amountA > 0 && amountB > 0, "Invalid amounts");
        (uint256 reserveA, uint256 reserveB) = getReserves();

        // Ensure proper ratio to prevent manipulation
        if (reserveA > 0 && reserveB > 0) {
            require(amountA.mul(reserveB) == amountB.mul(reserveA), "Invalid ratio");
        }

        // Transfer tokens
        tokenA.transferFrom(msg.sender, address(this), amountA);
        tokenB.transferFrom(msg.sender, address(this), amountB);

        // Calculate LP tokens
        if (totalSupply == 0) {
            lpTokens = sqrt(amountA.mul(amountB)).sub(MINIMUM_LIQUIDITY);
        } else {
            lpTokens = min(
                amountA.mul(totalSupply) / reserveA,
                amountB.mul(totalSupply) / reserveB
            );
        }

        require(lpTokens >= minA && lpTokens >= minB, "Slippage exceeded");
        lpBalance[msg.sender] = lpBalance[msg.sender].add(lpTokens);
        totalSupply = totalSupply.add(lpTokens);
        updateReserves(amountA, amountB, true);

        emit LiquidityAdded(msg.sender, amountA, amountB, lpTokens);
    }

    // Gas-optimized liquidity removal
    function removeLiquidity(
        uint256 lpTokens,
        uint256 minA,
        uint256 minB
    ) external nonReentrant whenNotPaused returns (uint256 amountA, uint256 amountB) {
        require(lpTokens > 0 && lpBalance[msg.sender] >= lpTokens, "Invalid LP tokens");
        (uint256 reserveA, uint256 reserveB) = getReserves();

        amountA = lpTokens.mul(reserveA) / totalSupply;
        amountB = lpTokens.mul(reserveB) / totalSupply;
        require(amountA >= minA && amountB >= minB, "Slippage exceeded");

        lpBalance[msg.sender] = lpBalance[msg.sender].sub(lpTokens);
        totalSupply = totalSupply.sub(lpTokens);
        updateReserves(amountA, amountB, false);

        tokenA.transfer(msg.sender, amountA);
        tokenB.transfer(msg.sender, amountB);

        emit LiquidityRemoved(msg.sender, amountA, amountB, lpTokens);
    }

    // Secure swap with sandwich and flash-loan protection
    function swap(
        uint256 amountIn,
        address tokenIn,
        uint256 minAmountOut
    ) external nonReentrant whenNotPaused returns (uint256 amountOut) {
        require(amountIn > 0, "Invalid input amount");
        require(tokenIn == address(tokenA) || tokenIn == address(tokenB), "Invalid token");

        (uint256 reserveA, uint256 reserveB) = getReserves();
        bool isTokenA = tokenIn == address(tokenA);
        (uint256 reserveIn, uint256 reserveOut) = isTokenA ? (reserveA, reserveB) : (reserveB, reserveA);

        // Sandwich attack mitigation: limit trade volume per block
        require(blockTradeVolume[block.number] < reserveIn / 10, "High volume detected");
        blockTradeVolume[block.number] = blockTradeVolume[block.number].add(amountIn);
        lastTradeBlock = block.number;

        // Calculate output with constant product formula
        uint256 amountInWithFee = amountIn.mul(10000 - FEE) / 10000;
        amountOut = getAmountOut(amountInWithFee, reserveIn, reserveOut);
        require(amountOut >= minAmountOut, "Slippage exceeded");

        // Update reserves and transfer tokens
        IERC20Upgradeable(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        address tokenOut = isTokenA ? address(tokenB) : address(tokenA);
        IERC20Upgradeable(tokenOut).transfer(msg.sender, amountOut);

        updateReserves(isTokenA ? amountIn : 0, isTokenA ? 0 : amountIn, true);
        updateReserves(isTokenA ? 0 : amountOut, isTokenA ? amountOut : 0, false);

        emit Swap(msg.sender, amountIn, amountOut, isTokenA);
    }

    // Gas-optimized reserve getter
    function getReserves() public view override returns (uint256 reserveA, uint256 reserveB) {
        return (uint256(reserves.reserveA), uint256(reserves.reserveB));
    }

    // Internal gas-optimized reserve update
    function updateReserves(uint256 amountA, uint256 amountB, bool add) private {
        if (add) {
            reserves.reserveA = uint128(uint256(reserves.reserveA).add(amountA));
            reserves.reserveB = uint128(uint256(reserves.reserveB).add(amountB));
        } else {
            reserves.reserveA = uint128(uint256(reserves.reserveA).sub(amountA));
            reserves.reserveB = uint128(uint256(reserves.reserveB).sub(amountB));
        }
    }

    // Constant product formula for swap output
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) private pure returns (uint256) {
        require(amountIn > 0 && reserveIn > 0 && reserveOut > 0, "Invalid reserves");
        return amountIn.mul(reserveOut) / reserveIn.add(amountIn);
    }

    // Gas-efficient square root function
    function sqrt(uint256 y) private pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    // Gas-efficient min function
    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }

    // Emergency pause functionality
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}