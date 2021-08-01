const hre = require("hardhat");
require("@nomiclabs/hardhat-ethers");
async function main() {
  const [deployer] = await ethers.getSigners();
  const block = await ethers.provider.getBlockNumber()
  const DD2NFT = await ethers.getContractFactory('DD2NFT');

  const Farm = await ethers.getContractFactory('Farm');

  const DD2TOKEN = await ethers.getContractFactory('DD2Token');

  const argsDeployNFT = ["DD2 NFT", "DD2-NFT"]
  const argsDeployTOKEN = ["100000000000000000000000000"]

  const dd2Nft = await DD2NFT.deploy("DD2 NFT", "DD2-NFT")
  console.log('DD2 NFT: ', dd2Nft.address)

  const dd2Token = await DD2TOKEN.deploy("100000000000000000000000000")
  console.log('DD2 Token: ', dd2Token.address)

  const argsDeployFARM = [dd2Token.address, 10, block, dd2Nft.address]
  const farm = await Farm.deploy(dd2Token.address, 10, block, dd2Nft.address)
  console.log('Farm: ', farm.address)

  //add  minter role for farm
  if ((await dd2Token.isMinter(farm.address)) == false) {
    console.log("Add minter role for farm");
    await (
      await dd2Token
        .connect(deployer)
        .addMinter(farm.address, "1000000000000000000000000")
    ).wait();
  }

  setTimeout(async () => {
    try {
      console.log('start verify')
      await hre.run("verify:verify", {
        address: dd2Token.address,
        constructorArguments: argsDeployTOKEN,
      });
      console.log('verify token done')
      await hre.run("verify:verify", {
        address: dd2Nft.address,
        constructorArguments: argsDeployNFT,
      });
      console.log('verify nft done')
      await hre.run("verify:verify", {
        address: farm.address,
        constructorArguments: argsDeployFARM,
      });
    } catch(e){
      console.log(e)
    }
  }, 10000)
  
}


main()
  .then()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
