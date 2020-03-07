const SlotMachineLogic = artifacts.require("SlotMachineLogic");
const RouletteLogic = artifacts.require("RouletteLogic");
const MasterParent = artifacts.require("MasterParent");
const Token = artifacts.require("Token");

module.exports = async function(deployer) {
  await deployer.deploy(Token);
  await deployer.deploy(SlotMachineLogic);
  await deployer.deploy(RouletteLogic);
  await deployer.deploy(MasterParent, Token.address, "MANA");
};
