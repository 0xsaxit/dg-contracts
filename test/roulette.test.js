const Roulette = artifacts.require("RouletteLogic");
const catchRevert = require("./exceptionsHelpers.js").catchRevert;

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
      roulette = await Roulette.new();
    });

    it("correct initial round timestamp", async () => {
      const ts = await roulette.getNextRoundTimestamp();

      const block = await web3.eth.getBlockNumber();
      const info = await web3.eth.getBlock(block);

      assert.equal(ts.toNumber(), info.timestamp);
    });

    it("correct initial bet amounts", async () => {
      const amount = await roulette.getAmountBets();
      assert.equal(amount, 0);
    });

    it("correct initial values", async () => {
      let payout;
      payout = await roulette.getPayoutForType(3301);
      assert.equal(payout, 36);

      payout = await roulette.getPayoutForType(3302);
      assert.equal(payout, 2);

      payout = await roulette.getPayoutForType(3303);
      assert.equal(payout, 2);

      payout = await roulette.getPayoutForType(3304);
      assert.equal(payout, 2);

      payout = await roulette.getPayoutForType(3305);
      assert.equal(payout, 2);

      payout = await roulette.getPayoutForType(3306);
      assert.equal(payout, 2);

      payout = await roulette.getPayoutForType(3307);
      assert.equal(payout, 2);

      payout = await roulette.getPayoutForType(3308);
      assert.equal(payout, 3);

      payout = await roulette.getPayoutForType(3309);
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
      roulette = await Roulette.new();
    });

    it("should let user create a single bet", async () => {
      await roulette.createBet(3301, user1, 2, 1000);
    });

    it("should emit NewSingleBet event", async () => {
      await roulette.createBet(3301, user1, 20, 1000);
      const event = await getLastEvent("NewSingleBet", roulette);

      assert(event);
    });

    it("should store bet in array", async () => {
      await roulette.createBet(3301, user1, 20, 1000);

      const userBet = await roulette.bets(0);

      assert.equal(userBet.betID.toNumber(), 3301);
      assert.equal(userBet.player, user1);
      assert.equal(userBet.number.toNumber(), 20);
      assert.equal(userBet.value.toNumber(), 1000);
      assert.equal(userBet.betType.toNumber(), 0);
    });
    it("event values should be the same as array", async () => {
      await roulette.createBet(3301, user1, 20, 1000);

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
      roulette = await Roulette.new();
    });

    it("should let user create an even bet", async () => {
      await roulette.createBet(3302, user1, 20, 1000);
    });

    it("should emit NewEvenBet event", async () => {
      await roulette.createBet(3302, user1, 20, 1000);
      const event = await getLastEvent("NewEvenBet", roulette);

      assert(event);
    });

    it("should store bet in array", async () => {
      await roulette.createBet(3302, user1, 20, 1000);

      const userBet = await roulette.bets(0);

      assert.equal(userBet.betID.toNumber(), 3302);
      assert.equal(userBet.player, user1);
      assert.equal(userBet.number.toNumber(), 0);
      assert.equal(userBet.value.toNumber(), 1000);
      assert.equal(userBet.betType.toNumber(), 2);
    });
    it("event values should be the same as array", async () => {
      await roulette.createBet(3302, user1, 20, 1000);

      const userBet = await roulette.bets(0);
      const { bet, player, value } = await getLastEvent("NewEvenBet", roulette);

      const res = await roulette.getBetsCountAndValue();
      assert.equal(res["0"], bet);
      assert.equal(player, userBet.player);
      assert.equal(value, userBet.value.toNumber());
    });
  });

  describe("Betting: Odd", () => {
    beforeEach(async () => {
      roulette = await Roulette.new();
    });

    it("should let user create an odd bet", async () => {
      await roulette.createBet(3303, user1, 20, 1000);
    });

    it("should emit NewOddBet event", async () => {
      await roulette.createBet(3303, user1, 20, 1000);
      const event = await getLastEvent("NewOddBet", roulette);

      assert(event);
    });

    it("should store bet in array", async () => {
      await roulette.createBet(3303, user1, 20, 1000);

      const userBet = await roulette.bets(0);

      assert.equal(userBet.betID.toNumber(), 3303);
      assert.equal(userBet.player, user1);
      assert.equal(userBet.number.toNumber(), 0);
      assert.equal(userBet.value.toNumber(), 1000);
      assert.equal(userBet.betType.toNumber(), 1);
    });
    it("event values should be the same as array", async () => {
      await roulette.createBet(3303, user1, 20, 1000);

      const userBet = await roulette.bets(0);
      const { bet, player, value } = await getLastEvent("NewOddBet", roulette);

      const res = await roulette.getBetsCountAndValue();
      assert.equal(res["0"], bet);
      assert.equal(player, userBet.player);
      assert.equal(value, userBet.value.toNumber());
    });
  });

  describe("Betting: Red", () => {
    beforeEach(async () => {
      roulette = await Roulette.new();
    });

    it("should let user create a red bet", async () => {
      await roulette.createBet(3304, user1, 20, 1000);
    });

    it("should emit NewRedBet event", async () => {
      await roulette.createBet(3304, user1, 20, 1000);
      const event = await getLastEvent("NewRedBet", roulette);

      assert(event);
    });

    it("should store bet in array", async () => {
      await roulette.createBet(3304, user1, 20, 1000);

      const userBet = await roulette.bets(0);

      assert.equal(userBet.betID.toNumber(), 3304);
      assert.equal(userBet.player, user1);
      assert.equal(userBet.number.toNumber(), 0);
      assert.equal(userBet.value.toNumber(), 1000);
      assert.equal(userBet.betType.toNumber(), 3);
    });
    it("event values should be the same as array", async () => {
      await roulette.createBet(3304, user1, 20, 1000);

      const userBet = await roulette.bets(0);
      const { bet, player, value } = await getLastEvent("NewRedBet", roulette);

      const res = await roulette.getBetsCountAndValue();
      assert.equal(res["0"], bet);
      assert.equal(player, userBet.player);
      assert.equal(value, userBet.value.toNumber());
    });
  });

  describe("Betting: Black", () => {
    beforeEach(async () => {
      roulette = await Roulette.new();
    });

    it("should let user create a black bet", async () => {
      await roulette.createBet(3305, user1, 20, 1000);
    });

    it("should emit NewBlackBet event", async () => {
      await roulette.createBet(3305, user1, 20, 1000);
      const event = await getLastEvent("NewBlackBet", roulette);

      assert(event);
    });

    it("should store bet in array", async () => {
      await roulette.createBet(3305, user1, 20, 1000);

      const userBet = await roulette.bets(0);

      assert.equal(userBet.betID.toNumber(), 3305);
      assert.equal(userBet.player, user1);
      assert.equal(userBet.number.toNumber(), 0);
      assert.equal(userBet.value.toNumber(), 1000);
      assert.equal(userBet.betType.toNumber(), 4);
    });
    it("event values should be the same as array", async () => {
      await roulette.createBet(3305, user1, 20, 1000);

      const userBet = await roulette.bets(0);
      const { bet, player, value } = await getLastEvent(
        "NewBlackBet",
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
      roulette = await Roulette.new();
    });

    it("should let user create a High bet", async () => {
      await roulette.createBet(3306, user1, 20, 1000);
    });

    it("should emit NewHighBet event", async () => {
      await roulette.createBet(3306, user1, 20, 1000);
      const event = await getLastEvent("NewHighBet", roulette);

      assert(event);
    });

    it("should store bet in array", async () => {
      await roulette.createBet(3306, user1, 20, 1000);

      const userBet = await roulette.bets(0);

      assert.equal(userBet.betID.toNumber(), 3306);
      assert.equal(userBet.player, user1);
      assert.equal(userBet.number.toNumber(), 0);
      assert.equal(userBet.value.toNumber(), 1000);
      assert.equal(userBet.betType.toNumber(), 5);
    });
    it("event values should be the same as array", async () => {
      await roulette.createBet(3306, user1, 20, 1000);

      const userBet = await roulette.bets(0);
      const { bet, player, value } = await getLastEvent("NewHighBet", roulette);

      const res = await roulette.getBetsCountAndValue();
      assert.equal(res["0"], bet);
      assert.equal(player, userBet.player);
      assert.equal(value, userBet.value.toNumber());
    });
  });

  describe("Betting: Low", () => {
    beforeEach(async () => {
      roulette = await Roulette.new();
    });

    it("should let user create a Low bet", async () => {
      await roulette.createBet(3307, user1, 20, 1000);
    });

    it("should emit NewLowBet event", async () => {
      await roulette.createBet(3307, user1, 20, 1000);
      const event = await getLastEvent("NewLowBet", roulette);

      assert(event);
    });

    it("should store bet in array", async () => {
      await roulette.createBet(3307, user1, 20, 1000);

      const userBet = await roulette.bets(0);

      assert.equal(userBet.betID.toNumber(), 3307);
      assert.equal(userBet.player, user1);
      assert.equal(userBet.number.toNumber(), 0);
      assert.equal(userBet.value.toNumber(), 1000);
      assert.equal(userBet.betType.toNumber(), 6);
    });
    it("event values should be the same as array", async () => {
      await roulette.createBet(3307, user1, 20, 1000);

      const userBet = await roulette.bets(0);
      const { bet, player, value } = await getLastEvent("NewLowBet", roulette);

      const res = await roulette.getBetsCountAndValue();
      assert.equal(res["0"], bet);
      assert.equal(player, userBet.player);
      assert.equal(value, userBet.value.toNumber());
    });
  });

  describe("Betting: Column", () => {
    beforeEach(async () => {
      roulette = await Roulette.new();
    });

    it("should let user create a Column bet", async () => {
      await catchRevert(roulette.createBet(3308, user1, 5, 1000));
      await roulette.createBet(3308, user1, 2, 1000);
    });

    it("should emit NewColumnBet event", async () => {
      await roulette.createBet(3308, user1, 2, 1000);
      const event = await getLastEvent("NewColumnBet", roulette);

      assert(event);
    });

    it("should store bet in array", async () => {
      await roulette.createBet(3308, user1, 2, 1000);

      const userBet = await roulette.bets(0);

      assert.equal(userBet.betID.toNumber(), 3308);
      assert.equal(userBet.player, user1);
      assert.equal(userBet.number.toNumber(), 2);
      assert.equal(userBet.value.toNumber(), 1000);
      assert.equal(userBet.betType.toNumber(), 7);
    });
    it("event values should be the same as array", async () => {
      await roulette.createBet(3308, user1, 2, 1000);

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
      roulette = await Roulette.new();
    });

    it("should let user create a Dozen bet", async () => {
      await catchRevert(roulette.createBet(3309, user1, 5, 1000));
      await roulette.createBet(3309, user1, 1, 1000);
    });

    it("should emit NewDozenBet event", async () => {
      await roulette.createBet(3309, user1, 2, 1000);
      const event = await getLastEvent("NewDozenBet", roulette);

      assert(event);
    });

    it("should store bet in array", async () => {
      await roulette.createBet(3309, user1, 1, 1000);

      const userBet = await roulette.bets(0);

      assert.equal(userBet.betID.toNumber(), 3309);
      assert.equal(userBet.player, user1);
      assert.equal(userBet.number.toNumber(), 1);
      assert.equal(userBet.value.toNumber(), 1000);
      assert.equal(userBet.betType.toNumber(), 8);
    });
    it("event values should be the same as array", async () => {
      await roulette.createBet(3309, user1, 1, 1000);

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
      roulette = await Roulette.new();
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
      await roulette.createBet(3301, user1, 20, 1000);
      await roulette.createBet(3302, user1, 20, 1000);
      await roulette.createBet(3303, user1, 20, 1000);
      await roulette.createBet(3304, user1, 20, 1000);
      await roulette.createBet(3305, user2, 20, 1000);
      await roulette.createBet(3306, user2, 20, 1000);
      await roulette.createBet(3307, user2, 20, 1000);
      await roulette.createBet(3308, user2, 2, 1000);
      await roulette.createBet(3309, user2, 1, 1000);
    });

    it("correct bet amount and value", async () => {
      const res = await roulette.getBetsCountAndValue();
      assert.equal(res["0"], 9);
      assert.equal(res["1"], 9000);
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
