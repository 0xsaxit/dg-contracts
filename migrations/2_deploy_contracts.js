const SlotMachineLogic = artifacts.require("SlotMachineLogic");
const RouletteLogic = artifacts.require("RouletteLogic");
const MasterParent = artifacts.require("MasterParent");
const Token = artifacts.require("Token");

const Treasury = artifacts.require("Treasury");
const TreasuryRoulette = artifacts.require("TreasuryRoulette");

module.exports = async function(deployer, network, accounts) {
  await deployer.deploy(Token);
  await deployer.deploy(MasterParent, Token.address, "MANA");

  await deployer.deploy(SlotMachineLogic, accounts[0], 250, 15, 8, 4, 100000);
  await deployer.deploy(RouletteLogic, accounts[0], 4000);

  await deployer.deploy(Treasury, Token.address, "MANA");
  await deployer.deploy(TreasuryRoulette, Treasury.address, 4000);

  // await deployer.deploy(SlotMachineLogic, MasterParent.address);
  // await deployer.deploy(RouletteLogic, MasterParent.address, 4000);
};
