const Token = artifacts.require("Token");
const Pointer = artifacts.require("dgPointer");
const Slots = artifacts.require("dgSlots");
const Treasury = artifacts.require("dgTreasury");
const catchRevert = require("./exceptionsHelpers.js").catchRevert;
const positions = [0, 16, 32, 48];

// require("./utils");

const getLastEvent = async (eventName, instance) => {
    const events = await instance.getPastEvents(eventName, {
        fromBlock: 0,
        toBlock: "latest"
    });

    //   console.log(events);
    return events.pop().returnValues;
};

contract("dgSlots", ([owner, newCEO, user1, user2, random]) => {
    let slots;

    before(async () => {
        token = await Token.new();
        pointer = await Pointer.new(token.address);
        slots = await Slots.new(owner, 250, 15, 8, 4, pointer.address, {from: owner});
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
            await slots.setWorker(user1, { from: owner });

            const event = await getLastEvent("WorkerSet", slots);
            assert.equal(event.newWorker, user1);
        });

        it("only Worker can pause the contract", async () => {
            await catchRevert(slots.pause({ from: random }));
            await slots.pause({ from: user1 });

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

        it("only CEO can set new factors", async () => {
            await catchRevert(slots.updateFactors(1, 2, 3, 4, { from: random }));

            let factor = await slots.getPayoutFactor(positions[0]);
            assert.equal(factor.toNumber(), 250);

            factor = await slots.getPayoutFactor(positions[1]);
            assert.equal(factor.toNumber(), 15);

            factor = await slots.getPayoutFactor(positions[2]);
            assert.equal(factor.toNumber(), 8);

            factor = await slots.getPayoutFactor(positions[3]);
            assert.equal(factor.toNumber(), 4);

            await slots.updateFactors(500, 100, 50, 25, { from: newCEO });

            factor = await slots.getPayoutFactor(positions[0]);
            assert.equal(factor.toNumber(), 500);

            factor = await slots.getPayoutFactor(positions[1]);
            assert.equal(factor.toNumber(), 100);

            factor = await slots.getPayoutFactor(positions[2]);
            assert.equal(factor.toNumber(), 50);

            factor = await slots.getPayoutFactor(positions[3]);
            assert.equal(factor.toNumber(), 25);
        });

        it("only CEO can set new treasury", async () => {
            await catchRevert(slots.updateTreasury(user2, { from: random }));
            await slots.updateTreasury(user2, { from: newCEO });
            const treasury = await slots.treasury();
            assert.equal(treasury, user2);
        });
    });

    describe("Game Play", () => {
        it("correct necessary balance calculation", async () => {
            const betA = 100;
            let factor = await slots.getPayoutFactor(positions[0]);
            let payout = await slots.getMaxPayout(betA);
            assert.equal(factor.toNumber() * betA, payout.toNumber());
        });
    });
});
