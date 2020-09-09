// const SlotMachineLogic = artifacts.require("SlotMachineLogic");
// const RouletteLogic = artifacts.require("RouletteLogic");
// const MasterParent = artifacts.require("MasterParent");
const Token = artifacts.require("Token");
const Treasury = artifacts.require("Treasury");
const dgRoulette = artifacts.require("dgRoulette");
const dgSlots = artifacts.require("dgSlots");
const dgBackgammon = artifacts.require("dgBackgammon");
const dgBlackJack = artifacts.require("dgBlackJack");
// const FAKEMana = artifacts.require("FAKEMana");

module.exports = async function(deployer, network, accounts) {

    // console.log(network);

    if (network == 'development') {

        // await deployer.deploy(MasterParent, Token.address, "MANA");

        // await deployer.deploy(SlotMachineLogic, accounts[0], 250, 15, 8, 4, 100000);
        // await deployer.deploy(RouletteLogic, accounts[0], 4000);

        await deployer.deploy(Token);
        await deployer.deploy(Treasury, Token.address, "MANA");
        await deployer.deploy(dgRoulette, Treasury.address, 4000, 36);
        await deployer.deploy(dgSlots, Treasury.address, 250, 15, 8, 4);

    }

    if (network == 'matic') {

        // await deployer.deploy(TreasuryFlat);
        // await deployer.deploy(dgRoulette, TreasuryFlat.address, "4000000000000000000000");
        // await deployer.deploy(FAKEMana);
        // await deployer.deploy(dgSlots, TreasuryFlat.address, 250, 15, 8, 4, "50000000000000000000");
        // await deployer.deploy(dgBackgammon, TreasuryFlat.address);
        // await treasury.addGame("0x0000000000000000000000000000000000000000", "Empty", 0, true, { from: owner });
        // await treasury.addGame(slots.address, "Slots", "1000000000000000000000", true, { from: owner });
        // await treasury.addGame(roulette.address, "Roulette", "50000000000000000000", true, { from: owner });

    }

    if (network == 'mumbai') {

        // await deployer.deploy(Treasury, '0x2A3df21E612d30Ac0CD63C3F80E1eB583A4744cC', 'MANA');
        // await deployer.deploy(dgSlots, Treasury.address, 250, 15, 8, 4);
        // await deployer.deploy(dgRoulette, Treasury.address, '4000000000000000000000', 36);
        // await deployer.deploy(dgBackgammon, Treasury.address, 64, 10);
        await deployer.deploy(dgBlackJack, '0x14Bb841662B1806E9Fa03286A0Db0B090eb8b416', 4);
        // await treasury.addGame("0x0000000000000000000000000000000000000000", "Empty", 0, true, { from: owner });
        // await treasury.addGame(dgSlots.address, "Slots", "1000000000000000000000", true, { from: owner });
        // await treasury.addGame(dgRoulette.address, "Roulette", "50000000000000000000", true, { from: owner });
        // await treasury.addGame(dgBackgammon.address, "Backgammon", "5000000000000000000", true, { from: owner });
        // await treasury.addGame(dgBackgammon.address, "Backgammon", "5000000000000000000", true, { from: owner });
    }

};
