// const SlotMachineLogic = artifacts.require("SlotMachineLogic");
// const RouletteLogic = artifacts.require("RouletteLogic");
// const MasterParent = artifacts.require("MasterParent");
const Token = artifacts.require("Token");
const dgTreasury = artifacts.require("dgTreasury");
const dgRoulette = artifacts.require("dgRoulette");
const dgSlots = artifacts.require("dgSlots");
const dgBackgammon = artifacts.require("dgBackgammon");
const dgBlackJack = artifacts.require("dgBlackJack");
const dgPointer = artifacts.require("dgPointer");
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

    // if (network == 'mumbai') {
    if (network == 'maticmain') {
        await deployer.deploy(dgPointer, '0xA1c57f48F0Deb89f569dFbE6E2B7f46D33606fD4');
        await deployer.deploy(dgTreasury, '0xA1c57f48F0Deb89f569dFbE6E2B7f46D33606fD4', 'MANA');
        await deployer.deploy(dgSlots, dgTreasury.address, 250, 15, 8, 4, dgPointer.address);
        await deployer.deploy(dgRoulette, dgTreasury.address, '4000000000000000000000', 36);
        // await deployer.deploy(dgRoulette, Treasury.address, '4000000000000000000000', 36, dgPointer.address');
        await deployer.deploy(dgBackgammon, dgTreasury.address, 64, 10, dgPointer.address);
        await deployer.deploy(dgBlackJack, '0x14Bb841662B1806E9Fa03286A0Db0B090eb8b416', dgPointer.address, 4);
        // await treasury.addGame("0x0000000000000000000000000000000000000000", "Empty", 0, true, { from: owner });
        // await treasury.addGame(dgSlots.address, "Slots", "1000000000000000000000", true, { from: owner });
        // await treasury.addGame(dgRoulette.address, "Roulette", "50000000000000000000", true, { from: owner });
        // await treasury.addGame(dgBackgammon.address, "Backgammon", "5000000000000000000", true, { from: owner });
        // await treasury.addGame(dgBackgammon.address, "Backgammon", "5000000000000000000", true, { from: owner });
    }

};
