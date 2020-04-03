const SlotMachineLogic = artifacts.require("SlotMachineLogic");
const RouletteLogic = artifacts.require("RouletteLogic");
const MasterParent = artifacts.require("MasterParent");
const Token = artifacts.require("Token");

module.exports = async function(deployer, network, accounts) {
  await deployer.deploy(Token);
  await deployer.deploy(SlotMachineLogic);
  await deployer.deploy(RouletteLogic, accounts[0], 4000);
  await deployer.deploy(MasterParent, Token.address, "MANA");
};
