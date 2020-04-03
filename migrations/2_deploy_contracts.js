const SlotMachineLogic = artifacts.require("SlotMachineLogic");
const RouletteLogic = artifacts.require("RouletteLogic");
const MasterParent = artifacts.require("MasterParent");
const Token = artifacts.require("Token");

module.exports = async function(deployer, network, accounts) {
  await deployer.deploy(Token);
  await deployer.deploy(MasterParent, Token.address, "MANA");

  await deployer.deploy(SlotMachineLogic, accounts[0]);
  await deployer.deploy(RouletteLogic, accounts[0], 4000);

  // await deployer.deploy(SlotMachineLogic, MasterParent.address);
  // await deployer.deploy(RouletteLogic, MasterParent.address, 4000);
};
