const SlotMachineLogic = artifacts.require("SlotMachineLogic");
const RouletteLogic = artifacts.require("RouletteLogic");
const MasterParent = artifacts.require("MasterParent");
const Token = artifacts.require("Token");

const Treasury = artifacts.require("Treasury");
const TreasuryFlat = artifacts.require("TreasuryFlat");

const TreasuryRoulette = artifacts.require("TreasuryRoulette");
const TreasurySlots = artifacts.require("TreasurySlots");
const TreasuryBackgammon = artifacts.require("TreasuryBackgammon");

module.exports = async function(deployer, network, accounts) {

    // console.log(network);

    if (network == 'development') {

        await deployer.deploy(Token);
        await deployer.deploy(MasterParent, Token.address, "MANA");

        await deployer.deploy(SlotMachineLogic, accounts[0], 250, 15, 8, 4, 100000);
        await deployer.deploy(RouletteLogic, accounts[0], 4000);

        await deployer.deploy(Treasury, Token.address, "MANA", "0x0000000000000000000000000000000000000000");
        await deployer.deploy(TreasuryRoulette, Treasury.address, 4000);
        await deployer.deploy(TreasurySlots, Treasury.address, 250, 15, 8, 4, 100000);

    }

    if (network == 'matic') {

        //await deployer.deploy(TreasuryFlat);
        await deployer.deploy(TreasuryBackgammon, "0x53ff23839cf62D670ad4b6777033Ad01A40591B9");
        //await deployer.deploy(TreasurySlots, TreasuryFlat.address, 250, 15, 8, 4, "50000000000000000000");
        // await treasury.addGame("0x0000000000000000000000000000000000000000", "Empty", 0, true, { from: owner });
        // await treasury.addGame(slots.address, "Slots", "1000000000000000000000", true, { from: owner });
        // await treasury.addGame(roulette.address, "Roulette", "50000000000000000000", true, { from: owner });

    }
};
