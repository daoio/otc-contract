const hre = require("hardhat");

async function main() {
  const EscrowFactory = await hre.ethers.getContractFactory("EscrowFactory");
  const escrowFactory = await EscrowFactory.deploy();

  await escrowFactory.deployed();

  console.log("Escrow Factory deployed to:", escrowFactory.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
