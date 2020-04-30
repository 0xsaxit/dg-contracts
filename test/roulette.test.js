const Roulette = artifacts.require("RouletteLogic");
const {catchRevert, catchSquareLimit} = require("./exceptionsHelpers.js");

require("./utils");

const getLastEvent = async (eventName, instance) => {
    const events = await instance.getPastEvents(eventName, {
        fromBlock: 0,
        toBlock: "latest"
    });
    return events.pop().returnValues;
};

contract("Roulette", ([owner, user1, user2, random]) => {
    let roulette;

    describe("Initial Variables", () => {
        beforeEach(async () => {
            roulette = await Roulette.new(owner, 4000);
        });

        it("correct initial round timestamp", async () => {
            const ts = await roulette.getNextRoundTimestamp();

            const block = await web3.eth.getBlockNumber();
            const info = await web3.eth.getBlock(block);

            assert.equal(ts.toNumber(), info.timestamp);
        });

        /* it("correct initial bet amounts", async () => {
            const amount = await roulette.getAmountBets();
            assert.equal(amount, 0);
        }); */

        it("correct initial values", async () => {
            let payout;
            payout = await roulette.getPayoutForType(0);
            assert.equal(payout, 36);

            payout = await roulette.getPayoutForType(1);
            assert.equal(payout, 2);

            payout = await roulette.getPayoutForType(2);
            assert.equal(payout, 2);

            payout = await roulette.getPayoutForType(3);
            assert.equal(payout, 2);

            payout = await roulette.getPayoutForType(4);
            assert.equal(payout, 3);

            payout = await roulette.getPayoutForType(5);
            assert.equal(payout, 3);
        });

        it("correct payout for type", async () => {
            const res = await roulette.getBetsCountAndValue();
            assert.equal(res["0"], 0);
            assert.equal(res["1"], 0);
        });
    });

    describe("Betting: Single", () => {
        beforeEach(async () => {
            roulette = await Roulette.new(owner, 4000);
        });

        it("should let user create a single bet", async () => {
            await roulette.createBet(0, user1, 2, 1000);
        });

        it("should emit NewSingleBet event", async () => {
            await roulette.createBet(0, user1, 20, 1000);
            const event = await getLastEvent("NewSingleBet", roulette);

            assert(event);
        });

        it("should store bet in array", async () => {
            await roulette.createBet(0, user1, 20, 1000);

            const userBet = await roulette.bets(0);

            assert.equal(userBet.player, user1);
            assert.equal(userBet.number.toNumber(), 20);
            assert.equal(userBet.value.toNumber(), 1000);
            assert.equal(userBet.betType.toNumber(), 0);
        });
        it("event values should be the same as array", async () => {
            await roulette.createBet(0, user1, 20, 1000);

            const userBet = await roulette.bets(0);
            const { bet, player, number, value } = await getLastEvent(
                "NewSingleBet",
                roulette
            );

            const res = await roulette.getBetsCountAndValue();
            assert.equal(res["0"], bet);

            assert.equal(player, userBet.player);
            assert.equal(number, userBet.number.toNumber());
            assert.equal(value, userBet.value.toNumber());
            assert.equal(userBet.betType.toNumber(), 0);
        });
    });

    describe("Betting: Even", () => {
        beforeEach(async () => {
            roulette = await Roulette.new(owner, 4000);
        });

        it("should let user create an even bet", async () => {
            await roulette.createBet(1, user1, 0, 1000);
        });

        it("should emit NewEvenOddBet event", async () => {
            await roulette.createBet(1, user1, 0, 1000);
            const event = await getLastEvent("NewEvenOddBet", roulette);

            assert(event);
        });

        it("should store bet in array", async () => {
            await roulette.createBet(1, user1, 0, 1000);

            const userBet = await roulette.bets(0);

            assert.equal(userBet.player, user1);
            assert.equal(userBet.number.toNumber(), 0);
            assert.equal(userBet.value.toNumber(), 1000);
            assert.equal(userBet.betType.toNumber(), 1);
        });
        it("event values should be the same as array", async () => {
            await roulette.createBet(1, user1, 0, 1000);

            const userBet = await roulette.bets(0);
            const { bet, player, value } = await getLastEvent("NewEvenOddBet", roulette);

            const res = await roulette.getBetsCountAndValue();
            assert.equal(res["0"], bet);
            assert.equal(player, userBet.player);
            assert.equal(value, userBet.value.toNumber());
        });
    });

    describe("Betting: Odd", () => {
        beforeEach(async () => {
            roulette = await Roulette.new(owner, 4000);
        });

        it("should let user create an odd bet", async () => {
            await roulette.createBet(1, user1, 1, 1000);
        });

        it("should emit NewEvenOddBet event", async () => {
            await roulette.createBet(1, user1, 1, 1000);
            const event = await getLastEvent("NewEvenOddBet", roulette);
            // check all values of event;
            assert(event);
        });

        it("should store bet in array", async () => {
            await roulette.createBet(1, user1, 1, 1000);

            const userBet = await roulette.bets(0);

            assert.equal(userBet.player, user1);
            assert.equal(userBet.number.toNumber(), 1);
            assert.equal(userBet.value.toNumber(), 1000);
            assert.equal(userBet.betType.toNumber(), 1);
        });
        it("event values should be the same as array", async () => {
            await roulette.createBet(1, user1, 1, 1000);

            const userBet = await roulette.bets(0);
            const { bet, player, value } = await getLastEvent("NewEvenOddBet", roulette);

            const res = await roulette.getBetsCountAndValue();
            assert.equal(res["0"], bet);
            assert.equal(player, userBet.player);
            assert.equal(value, userBet.value.toNumber());
        });
    });

    describe("Betting: Red", () => {
        beforeEach(async () => {
            roulette = await Roulette.new(owner, 4000);
        });

        it("should let user create a red bet", async () => {
            await roulette.createBet(2, user1, 0, 1000);
        });

        it("should emit NewRedBlackBet event", async () => {
            await roulette.createBet(2, user1, 0, 1000);
            const event = await getLastEvent("NewRedBlackBet", roulette);

            assert(event);
        });

        it("should store bet in array", async () => {
            await roulette.createBet(2, user1, 0, 1000);

            const userBet = await roulette.bets(0);

            assert.equal(userBet.player, user1);
            assert.equal(userBet.number.toNumber(), 0);
            assert.equal(userBet.value.toNumber(), 1000);
            assert.equal(userBet.betType.toNumber(), 2);
        });
        it("event values should be the same as array", async () => {
            await roulette.createBet(2, user1, 0, 1000);

            const userBet = await roulette.bets(0);
            const { bet, player, value } = await getLastEvent("NewRedBlackBet", roulette);

            const res = await roulette.getBetsCountAndValue();
            assert.equal(res["0"], bet);
            assert.equal(player, userBet.player);
            assert.equal(value, userBet.value.toNumber());
        });
    });

    describe("Betting: Black", () => {
        beforeEach(async () => {
            roulette = await Roulette.new(owner, 4000);
        });

        it("should let user create a black bet", async () => {
            await roulette.createBet(2, user1, 1, 1000);
        });

        it("should emit NewRedBlackBet event", async () => {
            await roulette.createBet(2, user1, 1, 1000);
            const event = await getLastEvent("NewRedBlackBet", roulette);

            assert(event);
        });

        it("should store bet in array", async () => {
            await roulette.createBet(2, user1, 1, 1000);

            const userBet = await roulette.bets(0);

            assert.equal(userBet.player, user1);
            assert.equal(userBet.number.toNumber(), 1);
            assert.equal(userBet.value.toNumber(), 1000);
            assert.equal(userBet.betType.toNumber(), 2);
        });
        it("event values should be the same as array", async () => {
            await roulette.createBet(2, user1, 1, 1000);

            const userBet = await roulette.bets(0);
            const { bet, player, value } = await getLastEvent(
                "NewRedBlackBet",
                roulette
            );

            const res = await roulette.getBetsCountAndValue();
            assert.equal(res["0"], bet);
            assert.equal(player, userBet.player);
            assert.equal(value, userBet.value.toNumber());
        });
    });

    describe("Betting: High", () => {
        beforeEach(async () => {
            roulette = await Roulette.new(owner, 4000);
        });

        it("should let user create a High bet", async () => {
            await roulette.createBet(3, user1, 0, 1000);
        });

        it("should emit NewHighLowBet event", async () => {
            await roulette.createBet(3, user1, 0, 1000);
            const event = await getLastEvent("NewHighLowBet", roulette);

            assert(event);
        });

        it("should store bet in array", async () => {
            await roulette.createBet(3, user1, 0, 1000);

            const userBet = await roulette.bets(0);

            assert.equal(userBet.player, user1);
            assert.equal(userBet.number.toNumber(), 0);
            assert.equal(userBet.value.toNumber(), 1000);
            assert.equal(userBet.betType.toNumber(), 3);
        });
        it("event values should be the same as array", async () => {
            await roulette.createBet(3, user1, 0, 1000);

            const userBet = await roulette.bets(0);
            const { bet, player, value } = await getLastEvent("NewHighLowBet", roulette);

            const res = await roulette.getBetsCountAndValue();
            assert.equal(res["0"], bet);
            assert.equal(player, userBet.player);
            assert.equal(value, userBet.value.toNumber());
        });
    });

    describe("Betting: Low", () => {
        beforeEach(async () => {
            roulette = await Roulette.new(owner, 4000);
        });

        it("should let user create a Low bet", async () => {
            await roulette.createBet(3, user1, 1, 1000);
        });

        it("should emit NewHighLowBet event", async () => {
            await roulette.createBet(3, user1, 1, 1000);
            const event = await getLastEvent("NewHighLowBet", roulette);

            assert(event);
        });

        it("should store bet in array", async () => {
            await roulette.createBet(3, user1, 1, 1000);

            const userBet = await roulette.bets(0);

            assert.equal(userBet.player, user1);
            assert.equal(userBet.number.toNumber(), 1);
            assert.equal(userBet.value.toNumber(), 1000);
            assert.equal(userBet.betType.toNumber(), 3);
        });
        it("event values should be the same as array", async () => {
            await roulette.createBet(3, user1, 1, 1000);

            const userBet = await roulette.bets(0);
            const { bet, player, value } = await getLastEvent("NewHighLowBet", roulette);

            const res = await roulette.getBetsCountAndValue();
            assert.equal(res["0"], bet);
            assert.equal(player, userBet.player);
            assert.equal(value, userBet.value.toNumber());
        });
    });

    describe("Betting: Column", () => {
        beforeEach(async () => {
            roulette = await Roulette.new(owner, 4000);
        });

        it("should let user create a Column bet", async () => {
            await catchRevert(roulette.createBet(4, user1, 5, 1000));
            await roulette.createBet(4, user1, 2, 1000);
        });

        it("should emit NewColumnBet event", async () => {
            await roulette.createBet(4, user1, 2, 1000);
            const event = await getLastEvent("NewColumnBet", roulette);

            assert(event);
        });

        it("should store bet in array", async () => {
            await roulette.createBet(4, user1, 2, 1000);
            const userBet = await roulette.bets(0);

            assert.equal(userBet.player, user1);
            assert.equal(userBet.number.toNumber(), 2);
            assert.equal(userBet.value.toNumber(), 1000);
            assert.equal(userBet.betType.toNumber(), 4);
        });
        it("event values should be the same as array", async () => {
            await roulette.createBet(4, user1, 2, 1000);

            const userBet = await roulette.bets(0);
            const { bet, player, value, column } = await getLastEvent(
                "NewColumnBet",
                roulette
            );

            const res = await roulette.getBetsCountAndValue();
            assert.equal(res["0"], bet);
            assert.equal(player, userBet.player);
            assert.equal(column, userBet.number);
            assert.equal(value, userBet.value.toNumber());
        });
    });

    describe("Betting: Dozen", () => {
        beforeEach(async () => {
            roulette = await Roulette.new(owner, 4000);
        });

        it("should let user create a Dozen bet", async () => {
            await catchRevert(roulette.createBet(5, user1, 5, 1000));
            await roulette.createBet(5, user1, 1, 1000);
        });

        it("should emit NewDozenBet event", async () => {
            await roulette.createBet(5, user1, 2, 1000);
            const event = await getLastEvent("NewDozenBet", roulette);
            assert(event);
        });

        it("should store bet in array", async () => {
            await roulette.createBet(5, user1, 1, 1000);
            const userBet = await roulette.bets(0);

            assert.equal(userBet.player, user1);
            assert.equal(userBet.number.toNumber(), 1);
            assert.equal(userBet.value.toNumber(), 1000);
            assert.equal(userBet.betType.toNumber(), 5);
        });
        it("event values should be the same as array", async () => {
            await roulette.createBet(5, user1, 1, 1000);

            const userBet = await roulette.bets(0);
            const { bet, player, value, dozen } = await getLastEvent(
                "NewDozenBet",
                roulette
            );

            const res = await roulette.getBetsCountAndValue();
            assert.equal(res["0"], bet);
            assert.equal(player, userBet.player);
            assert.equal(dozen, userBet.number);
            assert.equal(value, userBet.value.toNumber());
        });
    });

    describe("Betting: Launch", () => {
        before(async () => {
            roulette = await Roulette.new(owner, 4000);
        });

        it("should revert if current time is not greater than next round timestamp", async () => {
            const localHash =
                "0x2540a8d1ecac31d69ad55354fba8289cfbb61adac332291b1fe0a8c1011f1a2f";
            await catchRevert(
                roulette.launch(localHash, 1, 2, "MANA"),
                "revert expired round"
            );
        });

        it("should revert if there are no bets", async () => {
            await advanceTimeAndBlock(60);

            const localHash =
                "0x2540a8d1ecac31d69ad55354fba8289cfbb61adac332291b1fe0a8c1011f1a2f";
            await catchRevert(
                roulette.launch(localHash, 1, 2, "MANA"),
                "revert must have bets"
            );
        });

        it("should create different bets", async () => {
            await roulette.createBet(0, user1, 5, 1000);
            await roulette.createBet(1, user1, 0, 1000);
            await roulette.createBet(1, user1, 1, 1000);
            await roulette.createBet(2, user1, 0, 1000);
            await roulette.createBet(2, user2, 1, 1000);
            await roulette.createBet(3, user2, 0, 1000);
            await roulette.createBet(3, user2, 1, 1000);
            await roulette.createBet(4, user2, 2, 1000);
            await roulette.createBet(5, user2, 1, 1000);
        });

        it("correct bet amount and value", async () => {
            const res = await roulette.getBetsCountAndValue();
            assert.equal(res["0"], 9);
            assert.equal(res["1"], 9000);
        });

        it("correct bet square values", async () => {

            await roulette.createBet(0, user1, 5, 1000);
            await roulette.createBet(4, user2, 2, 2000);
            await roulette.createBet(5, user2, 1, 3000);

            const resA = await roulette.currentBets(0, 5);
            assert.equal(resA.toNumber(), 2000);
            const resB = await roulette.currentBets(4, 2);
            assert.equal(resB.toNumber(), 3000);
            const resC = await roulette.currentBets(5, 1);
            assert.equal(resC.toNumber(), 4000);
        });

        it("correct bet square values limits", async () => {
            await roulette.createBet(0, user1, 6, 4000);
            const resA = await roulette.currentBets(0, 6);
            assert.equal(resA.toNumber(), 4000);
        });

        it("should revert if exceeding square limit 4001", async () => {
            await advanceTimeAndBlock(60);
            await catchRevert(
                roulette.createBet(0, user1, 6, 4001),
                "revert exceeding maximum bet square limit"
            );
        });

        it("should revert if exceeding square limit 5000", async () => {
            await advanceTimeAndBlock(60);
            await roulette.createBet(0, user1, 7, 2000);
            await advanceTimeAndBlock(60);
            await catchRevert(
                roulette.createBet(0, user1, 7, 3000),
                "revert exceeding maximum bet square limit"
            );
        });

        it("should cleanup squares after the play", async () => {
            //create contract
            const rouletteB = await Roulette.new(owner, 4000);
            const localHash =
                "0x2540a8d1ecac31d69ad55354fba8289cfbb61adac332291b1fe0a8c1011f1a2f";

            //create bets
            await rouletteB.createBet(0, user2, 5, 1000);
            await rouletteB.createBet(4, user2, 2, 1000);
            await rouletteB.createBet(5, user2, 1, 1000);

            //check squares before the play
            const resA = await rouletteB.currentBets(0, 5);
            assert.equal(resA.toNumber(), 1000);
            const resB = await rouletteB.currentBets(4, 2);
            assert.equal(resB.toNumber(), 1000);
            const resC = await rouletteB.currentBets(5, 1);
            assert.equal(resC.toNumber(), 1000);

            //launch play
            await advanceTimeAndBlock(60);
            await rouletteB.launch(localHash, 1, 2, "MANA");
            await advanceTimeAndBlock(60);

            //check squares after play
            const resD = await rouletteB.currentBets(0, 5);
            assert.equal(resD.toNumber(), 0);
            const resE = await rouletteB.currentBets(4, 2);
            assert.equal(resE.toNumber(), 0);
            const resF = await rouletteB.currentBets(5, 1);
            assert.equal(resF.toNumber(), 0);

        });

        it("should only allow master contract to call script", async () => {
            await advanceTimeAndBlock(60);
            const rouletteA = await Roulette.new(user1, 4000);
            await advanceTimeAndBlock(60);
            await catchRevert(
                rouletteA.createBet(0, user1, 34, 1000),
                "revert can only be called by master/parent contract"
            );
        });

        it("should allow to chang master contract address", async () => {
            const rouletteA = await Roulette.new(user1, 4000);

            await advanceTimeAndBlock(60);
            await catchRevert(
                rouletteA.createBet(0, user1, 34, 1000),
                "revert can only be called by master/parent contract"
            );

            await rouletteA.changeMaster(user1);

            await rouletteA.createBet(0, user2, 5, 1000, { from: user1 });
            const resA = await rouletteA.currentBets(0, 5);
            const resB = await rouletteA.masterAddress();

            assert.equal(resA.toNumber(), 1000);
            assert.equal(resB, user1);
        });

        it("should be able to launch game", async () => {
            await advanceTimeAndBlock(60);

            const localHash =
                "0x2540a8d1ecac31d69ad55354fba8289cfbb61adac332291b1fe0a8c1011f1a2f";
            await roulette.launch(localHash, 1, 2, "MANA");

            const block = await web3.eth.getBlockNumber();
            const info = await web3.eth.getBlock(block);

            const {
                _tokenName,
                _landID,
                _machineID,
                _number,
                _amountWins
            } = await getLastEvent("SpinResult", roulette);
            // assert.equal(event2._walletAddress, user1);
            assert.equal(_tokenName, "MANA");
            assert.equal(_landID, 2);
            assert.equal(_machineID, 1);
        });

    });

});
