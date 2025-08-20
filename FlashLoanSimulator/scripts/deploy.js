const { ethers } = require("hardhat");
require("dotenv").config();

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying with:", deployer.address);

  // Deploy Tokens
  const TokenA = await ethers.getContractFactory("TokenA");
  const tokenA = await TokenA.deploy();
  await tokenA.deployed();
  console.log("TokenA:", tokenA.address);

  const TokenB = await ethers.getContractFactory("TokenB");
  const tokenB = await TokenB.deploy();
  await tokenB.deployed();
  console.log("TokenB:", tokenB.address);

  // Deploy DEX1: Factory and Router
  const UniswapV2Factory = await ethers.getContractFactory("UniswapV2Factory");
  const factory1 = await UniswapV2Factory.deploy(deployer.address);
  await factory1.deployed();
  console.log("DEX1 Factory:", factory1.address);

  const UniswapV2Router02 = await ethers.getContractFactory("UniswapV2Router02");
  const router1 = await UniswapV2Router02.deploy(factory1.address, tokenA.address); // WETH mock as TokenA
  await router1.deployed();
  console.log("DEX1 Router:", router1.address);

  // DEX2: Similar
  const factory2 = await UniswapV2Factory.deploy(deployer.address);
  await factory2.deployed();
  console.log("DEX2 Factory:", factory2.address);

  const router2 = await UniswapV2Router02.deploy(factory2.address, tokenA.address);
  await router2.deployed();
  console.log("DEX2 Router:", router2.address);

  // Create pairs
  await factory1.createPair(tokenA.address, tokenB.address);
  const pair1 = await factory1.getPair(tokenA.address, tokenB.address);
  console.log("DEX1 Pair:", pair1);

  await factory2.createPair(tokenA.address, tokenB.address);
  const pair2 = await factory2.getPair(tokenA.address, tokenB.address);
  console.log("DEX2 Pair:", pair2);

  // Deploy FlashLoanProvider with TokenA
  const FlashLoanProvider = await ethers.getContractFactory("FlashLoanProvider");
  const provider = await FlashLoanProvider.deploy(tokenA.address);
  await provider.deployed();
  console.log("FlashLoanProvider:", provider.address);

  // Fund provider with TokenA (transfer 500k)
  await tokenA.transfer(provider.address, ethers.utils.parseEther("500000"));
  console.log("Provider funded");

  // Deploy ArbitrageContract
  const ArbitrageContract = await ethers.getContractFactory("ArbitrageContract");
  const arb = await ArbitrageContract.deploy(
    provider.address,
    tokenA.address,
    tokenB.address,
    router1.address,
    router2.address
  );
  await arb.deployed();
  console.log("ArbitrageContract:", arb.address);

  // Save addresses to a file for Python (addresses.json)
  const fs = require("fs");
  const addresses = {
    tokenA: tokenA.address,
    tokenB: tokenB.address,
    dex1Router: router1.address,
    dex2Router: router2.address,
    flashLoanProvider: provider.address,
    arbitrageContract: arb.address,
    pair1: pair1,
    pair2: pair2
  };
  fs.writeFileSync("addresses.json", JSON.stringify(addresses, null, 2));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});