// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../LiquidityPool.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1_000_000 ether);
    }
}

contract LiquidityPoolTest is Test {
    LiquidityPool pool;
    MockToken tokenA;
    MockToken tokenB;
    address user1 = address(0x1);
    address user2 = address(0x2);
    address attacker = address(0x3);

    function setUp() public {
        tokenA = new MockToken("Token A", "TKA");
        tokenB = new MockToken("Token B", "TKB");
        pool = new LiquidityPool();
        pool.initialize(address(tokenA), address(tokenB));

        tokenA.transfer(user1, 100_000 ether);
        tokenB.transfer(user1, 100_000 ether);
        tokenA.transfer(user2, 100_000 ether);
        tokenB.transfer(user2, 100_000 ether);
        tokenA.transfer(attacker, 100_000 ether);
        tokenB.transfer(attacker, 100_000 ether);

        vm.startPrank(user1);
        tokenA.approve(address(pool), type(uint256).max);
        tokenB.approve(address(pool), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user2);
        tokenA.approve(address(pool), type(uint256).max);
        tokenB.approve(address(pool), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(attacker);
        tokenA.approve(address(pool), type(uint256).max);
        tokenB.approve(address(pool), type(uint256).max);
        vm.stopPrank();
    }

    function testAddLiquidity() public {
        vm.prank(user1);
        pool.addLiquidity(1000 ether, 1000 ether, 990 ether, 990 ether);
        (uint256 reserveA, uint256 reserveB) = pool.getReserves();
        assertEq(reserveA, 1000 ether);
        assertEq(reserveB, 1000 ether);
        assertEq(pool.lpBalance(user1), 1000 ether - 1000);
    }

    function testRemoveLiquidity() public {
        vm.startPrank(user1);
        pool.addLiquidity(1000 ether, 1000 ether, 990 ether, 990 ether);
        pool.removeLiquidity(500 ether, 495 ether, 495 ether);
        (uint256 reserveA, uint256 reserveB) = pool.getReserves();
        assertEq(reserveA, 500 ether);
        assertEq(reserveB, 500 ether);
        vm.stopPrank();
    }

    function testSwap() public {
        vm.startPrank(user1);
        pool.addLiquidity(1000 ether, 1000 ether, 990 ether, 990 ether);
        pool.swap(10 ether, address(tokenA), 9 ether);
        (uint256 reserveA, uint256 reserveB) = pool.getReserves();
        assertApproxEqAbs(reserveA, 1010 ether, 1 ether);
        assertApproxEqAbs(reserveB, 990 ether, 1 ether);
        vm.stopPrank();
    }

    function testReentrancyAttack() public {
        vm.startPrank(attacker);
        pool.addLiquidity(1000 ether, 1000 ether, 990 ether, 990 ether);
        vm.expectRevert("ReentrancyGuard: reentrant call");
        // Simulate reentrancy attack
        // Attacker contract would need to be deployed separately
        vm.stopPrank();
    }

    function testSandwichAttackMitigation() public {
        vm.startPrank(user1);
        pool.addLiquidity(1000 ether, 1000 ether, 990 ether, 990 ether);
        vm.stopPrank();

        vm.startPrank(attacker);
        // Try to manipulate price with large trade
        vm.expectRevert("High volume detected");
        pool.swap(200 ether, address(tokenA), 180 ether);
        vm.stopPrank();
    }

    function testSlippageProtection() public {
        vm.startPrank(user1);
        pool.addLiquidity(1000 ether, 1000 ether, 990 ether, 990 ether);
        vm.expectRevert("Slippage exceeded");
        pool.swap(10 ether, address(tokenA), 20 ether); // Unrealistic minAmountOut
        vm.stopPrank();
    }

    function testZeroLiquidityEdgeCase() public {
        vm.startPrank(user1);
        vm.expectRevert("Invalid amounts");
        pool.addLiquidity(0, 0, 0, 0);
        vm.stopPrank();
    }
}