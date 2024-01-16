// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  const ERC777TokenGTTContract = await hre.ethers.getContractFactory("ERC777TokenGTT");
  const GTT = await ERC777TokenGTTContract.deploy();
  await GTT.waitForDeployment();
  const ERC777TokenGTTAddr = GTT.target;
  console.log("ERC777TokenGTT contract has been deployed to: " + ERC777TokenGTTAddr);

  const NFTMarketContract = await hre.ethers.getContractFactory("NFTMarket");
  const NFTMarket = await NFTMarketContract.deploy(ERC777TokenGTTAddr);
  await NFTMarket.waitForDeployment();
  const NFTMarketAddr = NFTMarket.target;
  console.log("NFTMarket contract has been deployed to: " + NFTMarketAddr);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
