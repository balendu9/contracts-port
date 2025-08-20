const { ethers } = require("hardhat");
const addresses = require("../addresses.json"); // From deploy

async function main() {
  const [deployer] = await ethers.getSigners();

  const tokenA = await ethers.getContractAt("TokenA", addresses.tokenA);
  const tokenB = await ethers.getContractAt("TokenB", addresses.tokenB);
  const router1 = await ethers.getContractAt("IUniswapV2Router02", addresses.dex1Router);
  const router2 = await ethers.getContractAt("IUniswapV2Router02", addresses.dex2Router);

  // Approve
  await tokenA.approve(router1.address, ethers.utils.parseEther("100000"));
  await tokenB.approve(router1.address, ethers.utils.parseEther("100000"));
  await tokenA.approve(router2.address, ethers.utils.parseEther("100000"));
  await tokenB.approve(router2.address, ethers.utils.parseEther("100000"));

  // Add to DEX1: 1000 A : 1100 B (price B cheaper on DEX1)
  await router1.addLiquidity(
    addresses.tokenA,
    addresses.tokenB,
    ethers.utils.parseEther("1000"),
    ethers.utils.parseEther("1100"),
    0,
    0,
    deployer.address,
    Math.floor(Date.now() / 1000) + 60 * 10
  );

  // Add to DEX2: 1000 A : 900 B (price B expensive on DEX2)
  await router2.addLiquidity(
    addresses.tokenA,
    addresses.tokenB,
    ethers.utils.parseEther("1000"),
    ethers.utils.parseEther("900"),
    0,
    0,
    deployer.address,
    Math.floor(Date.now() / 1000) + 60 * 10
  );

  console.log("Liquidity added");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});