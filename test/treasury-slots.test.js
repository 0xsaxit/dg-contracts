const Slots = artifacts.require("TreasurySlots");
const Treasury = artifacts.require("Treasury");
const catchRevert = require("./exceptionsHelpers.js").catchRevert;
const positions = [192, 208, 224, 240];

// require("./utils");

const getLastEvent = async (eventName, instance) => {
    const events = await instance.getPastEvents(eventName, {
        fromBlock: 0,
        toBlock: "latest"
    });

    //   console.log(events);
    return events.pop().returnValues;
};

contract("TreasurySlots", ([owner, newCEO, user1, user2, random]) => {
    let slots;

    before(async () => {
        slots = await Slots.deployed(owner, 250, 15, 8, 4, 10000);
    });

    describe("Initial Variables", () => {
        it("correct worker address", async () => {
            const worker = await slots.workerAddress();
            assert.equal(worker, owner);
        });

        it("correct factor1 value", async () => {
            const factor = await slots.getPayoutFactor(positions[0]);
            assert.equal(factor, 250);
        });

        it("correct factor2 value", async () => {
            const factor = await slots.getPayoutFactor(positions[1]);
            assert.equal(factor, 15);
        });

        it("correct factor3 value", async () => {
            const factor = await slots.getPayoutFactor(positions[2]);
            assert.equal(factor, 8);
        });

        it("correct factor4 value", async () => {
            const factor = await slots.getPayoutFactor(positions[3]);
            assert.equal(factor, 4);
        });

        it("correct initial amount of bets", async () => {
            const amount = await slots.getAmountBets();
            assert.equal(amount, 0);
        });

        it("contract must be unpaused initially", async () => {
            const paused = await slots.paused();
            assert.equal(paused, false);
        });
    });

    describe("Access Control", () => {
        it("correct CEO address", async () => {
            const ceo = await slots.ceoAddress();
            assert.equal(ceo, owner);

            const event = await getLastEvent("CEOSet", slots);
            assert.equal(event.newCEO, owner);
        });

        it("only CEO can set a new CEO Address", async () => {
            await catchRevert(slots.setCEO(newCEO, { from: random }));
            await slots.setCEO(newCEO, { from: owner });

            const event = await getLastEvent("CEOSet", slots);
            assert.equal(event.newCEO, newCEO);
        });

        it("only CEO can set a new worker Address", async () => {
            await catchRevert(slots.setWorker(user1, { from: random }));
            await slots.setWorker(user1, { from: newCEO });

            const event = await getLastEvent("WorkerSet", slots);
            assert.equal(event.newWorker, user1);
        });

        it("only CEO can pause the contract", async () => {
            await catchRevert(slots.pause({ from: random }));
            await slots.pause({ from: newCEO });

            const event = await getLastEvent("Paused", slots);
            assert(event);

            const paused = await slots.paused();
            assert.equal(paused, true);
        });

        it("only CEO can unpause the contract", async () => {
            await catchRevert(slots.unpause({ from: random }));
            await slots.unpause({ from: newCEO });

            const event = await getLastEvent("Unpaused", slots);
            assert(event);

            const paused = await slots.paused();
            assert.equal(paused, false);
        });

        it("only CEO can set new settings", async () => {
            await catchRevert(slots.updateSettings(user1, 1, 2, 3, 4, { from: random }));
            await slots.updateSettings(user1, 250, 15, 8, 4, { from: newCEO });

            const factor = await slots.getPayoutFactor(positions[0]);
            assert.equal(factor.toNumber(), 250);
        });
    });

    describe("Game Play", () => {
        it("correctly create a bet", async () => {
            let slotsNew = await Slots.new(owner, 250, 15, 8, 4, 10000);
            await slotsNew.createBet(0, user1, 0, 100, "MANA");
            const amount = await slotsNew.getAmountBets();
            assert.equal(amount, 1);
        });

        it("correctly launches gameplay", async () => {
            let slotsNew = await Slots.new(owner, 250, 15, 8, 4, 10000);
            localHash =
                "0xb3c529065a012035b65655465a52ad426f830a8e1ae7f4dd1ef590b41d09f05d";

            await slotsNew.createBet(0, user1, 0, 100, "MANA");
            const amount = await slotsNew.getAmountBets();
            assert.equal(amount, 1);
            await slotsNew.launch(localHash, 1, 2, "MANA");

            const {
                _tokenName,
                _landID ,
                _winAmounts
            } = await getLastEvent("SpinResult", slotsNew);
            assert.equal(JSON.stringify(_winAmounts), JSON.stringify(['0']));
            assert.equal(_tokenName, "MANA");
            assert.equal(_landID, 2);
        });

        it("should only allow master contract to call script", async () => {
            // await advanceTimeAndBlock(60);
            const slotsA = await Slots.new(user1, 250, 15, 8, 4, 10000);
            // await advanceTimeAndBlock(60);
            await catchRevert(
                slotsA.createBet(0, user1, 0, 1000, "MANA", { from: user1 }),
                "revert can only be called by master/parent contract"
            );
        });


        /*it("should allow to change treasury address", async () => {
            const slotsA = await Slots.new(user1, 250, 15, 8, 4, 10000);
            // await advanceTimeAndBlock(60);
            await catchRevert(
                slotsA.createBet(0, user1, 0, 1000, "MANA"),
                "revert can only be called by master/parent contract"
            );
            await slotsA.updateSettings(user1, 0, 0, 0, 0);
            await slotsA.createBet(0, user2, 0, 1000, "MANA", { from: user1 });
        });*/


        it("correct win amount", async () => {
            const slotsA = await Slots.new(owner, 250, 15, 8, 4, 10000);
            const Bet = 100
            await slotsA.createBet(0, user1, 0, Bet, "MANA");

            const hash =
                "0x974ad959476b4156e4f324b692d9ad9af68af768041b6b014b36f1bc4cab7a13";

            const numbers = web3.utils.hexToNumberString(
                web3.utils.soliditySha3(hash)
            );

            const number = numbers.slice(numbers.length - 3);

            symbols = [4, 4, 4, 4, 3, 3, 3, 2, 2, 1];
            factors = {
                "1": 250,
                "2": 15,
                "3": 8,
                "4": 4
            };

            await slotsA.launch(hash, 1, 2, "MANA");
            const { _winAmounts, _number } = await getLastEvent("SpinResult", slotsA);

            assert.equal(_winAmounts[0], Bet * factors[symbols[number % 10]]);
            assert.equal(_number, number);
        });

        it("correct payout for type", async () => {
            let factor = await slots.getPayoutFactor(positions[0]);
            assert.equal(factor.toNumber(), 250);
        });

        it("correct necessary balance calculation", async () => {
            let _necessaryBalance
            const betA = 100;
            const betB = 200;
            const slotsA = await Slots.new(user2, 250, 15, 8, 4, 10000);

            const factor = await slotsA.getPayoutFactor(positions[0]);

            await slotsA.createBet(0, user2, 0, betA, "MANA");
            _necessaryBalance = await slotsA.getNecessaryBalance();
            assert.equal(_necessaryBalance.toNumber(), factor * betA);

            await slotsA.createBet(0, user1, 0, betB, "MANA");
            _necessaryBalance = await slotsA.getNecessaryBalance();
            assert.equal(_necessaryBalance.toNumber(), factor * (betA + betB));
        });
    });
});
