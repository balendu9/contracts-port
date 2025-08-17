pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../YieldVault.sol";
import "../Strategy.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Mock Token", "MTK") {
        _mint(msg.sender, 1_000_000 * 1e18);
    }
}

contract MockOracle {
    function getPrice(address) external pure returns (uint256) {
        return 1e18; // Mock price
    }
}

contract YieldVaultTest is Test {
    YieldVault vault;
    Strategy strategy;
    MockToken token;
    MockOracle oracle;
    address user = address(0x1);
    address owner = address(0x2);

    function setUp() public {
        token = new MockToken();
        oracle = new MockOracle();
        vault = new YieldVault();
        vault.initialize(address(token), address(oracle), 200, 50); // 2% fee, 0.5% slippage
        strategy = new Strategy(address(vault), address(token), address(0x3));
        vm.prank(owner);
        vault.setStrategy(address(strategy));
        vm.deal(user, 100 ether);
        vm.startPrank(user);
        token.approve(address(vault), type(uint256).max);
    }

    function testDeposit() public {
        uint256 amount = 1000 * 1e18;
        token.transfer(user, amount);
        vault.deposit(amount);
        assertEq(vault.shares(user), amount); // 1:1 share price initially
        assertEq(token.balanceOf(address(vault)), amount);
    }

    function testWithdraw() public {
        uint256 amount = 1000 * 1e18;
        token.transfer(user, amount);
        vault.deposit(amount);
        vault.withdraw(amount);
        assertEq(vault.shares(user), 0);
        assertEq(token.balanceOf(user), amount);
    }

    function testHarvest() public {
        // Simulate profit in strategy
        uint256 amount = 1000 * 1e18;
        token.transfer(user, amount);
        vault.deposit(amount);
        vm.prank(owner);
        vault.harvest();
        // Add assertions for profit and fee
    }

    function testFailSlippage() public {
        // Simulate oracle price deviation
        // Test slippage protection
    }

    function testFailReentrancy() public {
        // Simulate reentrancy attack
    }

    // Add more tests for edge cases
}