const Roulette = artifacts.require("TreasuryRoulette");
const Slots = artifacts.require("TreasurySlots");
const Treasury = artifacts.require("Treasury");
const Token = artifacts.require("Token");

const catchRevert = require("./exceptionsHelpers.js").catchRevert;

require("./utils");
require("colors");

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

const HASH_CHAIN = [
    "0x7f7e3e79bc27e06158e71e3d1ad06c358ac9634e29875cd95c3041e0206494d5",
    "0xd3ea1389b1549688059ed3bb1c8d9fe972389e621d1341ec4340dc468fd5576d",
    "0x85b19f01fe40119c675666a851d9e6b9a85424dc4016b2de0bdb69efecf08dea",
    "0x28ecea1ba1f63e6973e214182b87fce258a89705e40360fddcf00cad0f905730",
    "0xd1f07819ba177c9c9977dade4370f99942f8a5e24ea36750207d890293c7866f",
    "0x5ef64968497705b2ad68ed5ebb3a8edd478a5cab3e443cb44429bc9de7766149",
    "0xf8bf31336d2f22ffb04bff206dc338f4f96ffd243281fdc2268435d92f70988f"
];

const getLastEvent = async (eventName, instance) => {
    const events = await instance.getPastEvents(eventName, {
        fromBlock: 0,
        toBlock: "latest"
    });
    return events.pop().returnValues;
};

contract("Treasury", ([owner, user1, user2, user3, random]) => {

    let roulette, slots, token, treasury;

    describe("Initial Values", () => {
        before(async () => {
            token = await Token.new();
            treasury = await Treasury.new(token.address, "MANA", ZERO_ADDRESS);
        });

        it("correct default token name and address", async () => {
            const tokenName = await treasury.defaultTokenName();
            assert.equal(tokenName, "MANA");

            const tokenAddress = await treasury.tokens("MANA");
            assert.equal(tokenAddress, token.address);

            const tokenName0 = await treasury.tokenNames(0);
            assert.equal(tokenName0, "MANA");
        });

        it("correct CEO address", async () => {
            const ceo = await treasury.ceoAddress();
            assert.equal(ceo, owner);

            const event = await getLastEvent("CEOSet", treasury);
            assert.equal(event.newCEO, owner);
        });

        it("correct worker address", async () => {
            const worker = await treasury.workerAddress();
            assert.equal(worker, owner);
        });
    });

    describe("Adding Games", () => {

        beforeEach(async () => {
            token = await Token.new();
            treasury = await Treasury.new(token.address, "MANA", ZERO_ADDRESS);
            roulette = await Roulette.new(treasury.address, 4000);
            slots = await Slots.new(treasury.address, 250, 16, 8, 4, 1000000000000000);
        });

        it("only CEO can add a game", async () => {
            await catchRevert(
                treasury.addGame(slots.address, "Slots", 100, false, { from: random })
            );
            await treasury.addGame(slots.address, "Slots", 100, false, { from: owner });
        });

        it("correct game details after added", async () => {
            await treasury.addGame(slots.address, "Slots", 100, false, { from: owner });
            await treasury.addGame(roulette.address, "Roulette", 200, false, { from: owner });

            const slotsInfo = await treasury.games(0);
            const slotsMaxBet = await treasury.gameMaximumBet(0, "MANA");
            assert.equal(slotsInfo.gameAddress, slots.address);
            assert.equal(slotsInfo.gameName, "Slots");
            assert.equal(slotsMaxBet, 100);

            const rouletteInfo = await treasury.games(1);
            const rouletteMaxBet = await treasury.gameMaximumBet(1, "MANA");
            assert.equal(rouletteInfo.gameAddress, roulette.address);
            assert.equal(rouletteInfo.gameName, "Roulette");
            assert.equal(rouletteMaxBet, 200);
        });
    });

    describe("Adding Funds to a Game", () => {
        beforeEach(async () => {
            token = await Token.new();
            treasury = await Treasury.new(token.address, "MANA", ZERO_ADDRESS);
            roulette = await Roulette.new(treasury.address, 4000);
            slots = await Slots.new(treasury.address, 250, 16, 8, 4, 1000000);
            await treasury.addGame(slots.address, "Slots", 100, true, { from: owner });
            await treasury.addGame(roulette.address, "Roulette", 200, true, { from: owner });
        });

        it("should revert if token is not approved first", async () => {
            await catchRevert(treasury.addFunds(0, 1000, "MANA", { from: owner }));
            await token.approve(treasury.address, 1000);
            await treasury.addFunds(0, 1000, "MANA", { from: owner });
        });

        it("should revert if token is not registered first", async () => {
            await catchRevert(treasury.addFunds(0, 1000, "MANA", { from: owner }));
            await token.approve(treasury.address, 1000);
            await treasury.addFunds(0, 1000, "MANA", { from: owner });
            await catchRevert(treasury.addFunds(0, 1000, "DAI", { from: owner }));
        });

        it("should revert if user does not have enough funds", async () => {
            await token.approve(treasury.address, 0, { from: random });
            await catchRevert(treasury.addFunds(0, 1000, "MANA", { from: random }));
        });

        it("should emit NewBalance event", async () => {
            await token.approve(treasury.address, 1000);
            await treasury.addFunds(0, 1000, "MANA", { from: owner });

            const { _gameID, _balance } = await getLastEvent("NewBalance", treasury);
            assert.equal(_gameID, 0);
            assert.equal(_balance, 1000);
        });

        it("contract token balance should update to funds sent", async () => {
            await token.approve(treasury.address, 1000);
            await treasury.addFunds(0, 1000, "MANA", { from: owner });

            const balance = await token.balanceOf(treasury.address);
            assert.equal(balance, 1000);
        });

        it("correct allocated tokens in game", async () => {
            await token.approve(treasury.address, 1000);
            await treasury.addFunds(0, 1000, "MANA", { from: owner });

            const allocated = await treasury.checkAllocatedTokensPerGame(0, "MANA");
            assert.equal(allocated, 1000);
        });
    });

    describe("Removing Funds", () => {
        beforeEach(async () => {
            token = await Token.new();
            treasury = await Treasury.new(token.address, "MANA", ZERO_ADDRESS);
            roulette = await Roulette.new(treasury.address, 4000);
            await treasury.addGame(roulette.address, "Roulette", 200, true, { from: owner });
            await token.approve(treasury.address, 1000, { from: owner });
            await treasury.addFunds(0, 1000, "MANA", { from: owner });
        });

        it("only CEO can remove funds from a game", async () => {
            await catchRevert(
                treasury.withdrawTokens(0, 1000, "MANA", { from: random })
            );
            treasury.withdrawTokens(0, 1000, "MANA", { from: owner });
        });

        it("should revert if amount value is greater than game funds", async () => {
            await catchRevert(
                treasury.withdrawTokens(0, 2000, "MANA", { from: owner })
            );
            treasury.withdrawTokens(0, 1000, "MANA", { from: owner })
            await catchRevert(
                treasury.withdrawTokens(0, 1, "MANA", { from: owner })
            );
        });

        it("CEO should be able to remove funds", async () => {
            await treasury.withdrawTokens(0, 1000, "MANA", { from: owner });
            const allocated = await treasury.checkAllocatedTokensPerGame(0, "MANA");
            assert.equal(allocated, 0);
        });

        it("should emit NewBalance event", async () => {
            await treasury.withdrawTokens(0, 500, "MANA", { from: owner });

            const { _gameID, _balance } = await getLastEvent("NewBalance", treasury);
            assert.equal(_gameID, 0);
            assert.equal(_balance, 500);
        });

        it("correct game balance after withdrawl", async () => {
            await treasury.withdrawTokens(0, 200, "MANA", { from: owner });

            const allocated = await treasury.checkAllocatedTokensPerGame(0, "MANA");
            assert.equal(allocated, 800);
        });

        it("correct CEO balance after withdraw", async () => {
            const initialTreasuryBalance = await token.balanceOf(treasury.address);
            const initialOwnerBalance = await token.balanceOf(owner);

            assert.equal(initialTreasuryBalance, 1000);
            // assert.equal(web3.utils.fromWei(initialOwnerBalance), 1000);

            await treasury.withdrawTokens(0, 200, "MANA", { from: owner });

            const finalOwnerBalance = await token.balanceOf(owner);
            const finalTreasuryBalance = await token.balanceOf(treasury.address);

            const newOwnerBalance = initialOwnerBalance + initialTreasuryBalance;

            //console.log(web3.utils.fromWei(finalOwnerBalance));
            // console.log(web3.utils.fromWei(newOwnerBalance));

            assert(finalOwnerBalance > initialOwnerBalance);
            assert.equal(finalTreasuryBalance, 800);
            // assert.equal(finalOwnerBalance, newOwnerBalance);
        });

        it("only CEO can remove all token balance of contract", async () => {
            await catchRevert(
                treasury.withdrawMaxTokens("MANA", { from: random })
            );
            await treasury.withdrawMaxTokens("MANA", { from: owner });

            const allocated = await treasury.checkAllocatedTokensPerGame(0, "MANA");
            assert.equal(allocated, 0);
            const balance = await token.balanceOf(treasury.address);
            assert.equal(balance, 0);
        });
    });

    describe("Game Play: Roulette", () => {
        const betTypes = [0, 2, 5];
        const betValues = [20, 1, 1];
        const betAmount = [500, 300, 400];

        beforeEach(async () => {
            token = await Token.new();
            treasury = await Treasury.new(token.address, "MANA", ZERO_ADDRESS);
            roulette = await Roulette.new(treasury.address, 4000);
            await treasury.addGame(roulette.address, "Roulette", 1000, true, { from: owner });
            await token.approve(treasury.address, web3.utils.toWei("100"));
            await treasury.addFunds(0, web3.utils.toWei("100"), "MANA", {
                from: owner
            });
            await token.transfer(user1, 10000);
            await token.transfer(user2, 10000);
            await token.transfer(user3, 10000);
            await treasury.setTail(
                "0x7f7e3e79bc27e06158e71e3d1ad06c358ac9634e29875cd95c3041e0206494d5",
                { from: owner }
            );
        });

        it("only CEO can set tail", async () => {
            await catchRevert(
                treasury.setTail(
                    "0xd1f07819ba177c9c9977dade4370f99942f8a5e24ea36750207d890293c7866f",
                    { from: random }
                )
            );
            await treasury.setTail(
                "0xd1f07819ba177c9c9977dade4370f99942f8a5e24ea36750207d890293c7866f",
                { from: owner }
            );
        });

        it("should be able to play game", async () => {
            await token.approve(treasury.address, 5000, { from: user1 });
            await token.approve(treasury.address, 5000, { from: user2 });
            await token.approve(treasury.address, 5000, { from: user3 });
            await advanceTimeAndBlock(60);
            await roulette.play(
                [user1, user2, user3],
                1,
                2,
                betTypes,
                betValues,
                betAmount,
                "0xd3ea1389b1549688059ed3bb1c8d9fe972389e621d1341ec4340dc468fd5576d",
                "MANA",
                { from: owner }
            );
        });

        it("play function can only be called by worker", async () => {
            await token.approve(treasury.address, 5000, { from: user1 });
            await token.approve(treasury.address, 5000, { from: user2 });
            await token.approve(treasury.address, 5000, { from: user3 });
            await advanceTimeAndBlock(60);

            await catchRevert(
                roulette.play(
                    [user1, user2, user3],
                    1,
                    2,
                    betTypes,
                    betValues,
                    betAmount,
                    "0xd3ea1389b1549688059ed3bb1c8d9fe972389e621d1341ec4340dc468fd5576d",
                    "MANA",
                    { from: random }
                ),
                "revert"
            );

            await roulette.play(
                [user1, user2, user3],
                1,
                2,
                betTypes,
                betValues,
                betAmount,
                "0xd3ea1389b1549688059ed3bb1c8d9fe972389e621d1341ec4340dc468fd5576d",
                "MANA",
                { from: owner }
            );
        });

        it("user has to approve the transfer of tokens from treasury first", async () => {
            await catchRevert(
                roulette.play(
                    [user1, user2, user3],
                    1,
                    2,
                    betTypes,
                    betValues,
                    betAmount,
                    "0xd3ea1389b1549688059ed3bb1c8d9fe972389e621d1341ec4340dc468fd5576d",
                    "MANA",
                    { from: owner }
                ),
                "revert approve treasury as spender"
            );

            await token.approve(treasury.address, 5000, { from: user1 });
            await token.approve(treasury.address, 5000, { from: user2 });
            await token.approve(treasury.address, 5000, { from: user3 });
            await advanceTimeAndBlock(60);
            await roulette.play(
                [user1, user2, user3],
                1,
                2,
                betTypes,
                betValues,
                betAmount,
                "0xd3ea1389b1549688059ed3bb1c8d9fe972389e621d1341ec4340dc468fd5576d",
                "MANA",
                { from: owner }
            );
        });

        it("should revert if bet amount and values are not equal length", async () => {
            await token.approve(treasury.address, 5000, { from: user1 });
            await token.approve(treasury.address, 5000, { from: user2 });
            await token.approve(treasury.address, 5000, { from: user3 });

            await catchRevert(
                roulette.play(
                    [user1, user2, user3],
                    1,
                    2,
                    [0, 0], // Arrays not equal length
                    betValues,
                    betAmount,
                    "0xd3ea1389b1549688059ed3bb1c8d9fe972389e621d1341ec4340dc468fd5576d",
                    "MANA",
                    { from: owner }
                ),
                "revert inconsistent amount of bets"
            );
        });

        it("should revert if it exceeds maximum amount of game bet", async () => {
            await token.approve(treasury.address, 5000, { from: user1 });
            await token.approve(treasury.address, 5000, { from: user2 });
            await token.approve(treasury.address, 5000, { from: user3 });
            await catchRevert(
                roulette.play(
                    [user1, user2, user3],
                    1,
                    2,
                    betTypes,
                    betValues,
                    [500, 300, 3000],
                    "0xd3ea1389b1549688059ed3bb1c8d9fe972389e621d1341ec4340dc468fd5576d",
                    "MANA",
                    { from: owner }
                ),
                "revert bet amount is more than maximum"
            );
        });

        it("should emit a GameResult event with correct details", async () => {
            await token.approve(treasury.address, 5000, { from: user1 });
            await token.approve(treasury.address, 5000, { from: user2 });
            await token.approve(treasury.address, 5000, { from: user3 });
            await advanceTimeAndBlock(60);
            await roulette.play(
                [user1, user2, user3],
                1,
                2,
                betTypes,
                betValues,
                betAmount,
                "0xd3ea1389b1549688059ed3bb1c8d9fe972389e621d1341ec4340dc468fd5576d",
                "MANA",
                { from: owner }
            );
            const { _players, _tokenName, _landID, _machineID } = await getLastEvent(
                "GameResult",
                roulette
            );

            assert.equal(
                JSON.stringify(_players),
                JSON.stringify([user1, user2, user3])
            );
            assert.equal(_tokenName, "0x4605d046b0132734b6fc45e75049e1422f8ec9d9cdeec93f928bdb57662cecdc");
            assert.equal(_landID, 1);
            assert.equal(_machineID, 2);
        });

        it("should revert if uses same local hash after a play", async () => {
            await token.approve(treasury.address, 5000, { from: user1 });
            await token.approve(treasury.address, 5000, { from: user2 });
            await token.approve(treasury.address, 5000, { from: user3 });
            await advanceTimeAndBlock(60);
            await roulette.play(
                [user1, user2, user3],
                1,
                2,
                betTypes,
                betValues,
                betAmount,
                "0xd3ea1389b1549688059ed3bb1c8d9fe972389e621d1341ec4340dc468fd5576d",
                "MANA",
                { from: owner }
            );

            await catchRevert(
                roulette.play(
                    [user1, user2, user3],
                    1,
                    2,
                    betTypes,
                    betValues,
                    betAmount,
                    "0xd3ea1389b1549688059ed3bb1c8d9fe972389e621d1341ec4340dc468fd5576d",
                    "MANA",
                    { from: owner }
                ),
                "revert hash-chain: wrong parent"
            );
        });

        it("should be able to play if uses correct next local hash after a play", async () => {
            await token.approve(treasury.address, 5000, { from: user1 });
            await token.approve(treasury.address, 5000, { from: user2 });
            await token.approve(treasury.address, 5000, { from: user3 });
            await advanceTimeAndBlock(60);
            await roulette.play(
                [user1, user2, user3],
                1,
                2,
                betTypes,
                betValues,
                betAmount,
                "0xd3ea1389b1549688059ed3bb1c8d9fe972389e621d1341ec4340dc468fd5576d",
                "MANA",
                { from: owner }
            );

            await advanceTimeAndBlock(60);
            await roulette.play(
                [user1, user2, user3],
                1,
                2,
                betTypes,
                betValues,
                betAmount,
                "0x85b19f01fe40119c675666a851d9e6b9a85424dc4016b2de0bdb69efecf08dea",
                "MANA",
                { from: owner }
            );
        });
    });

    describe("Game Results: Roulette", () => {
        const betTypes = [0, 2, 5, 1, 3];
        const betValues = [31, 0, 2, 1, 1];
        const betAmounts = [500, 300, 400, 100, 200];

        beforeEach(async () => {
            // Deploy contracts
            token = await Token.new();
            treasury = await Treasury.new(token.address, "MANA", ZERO_ADDRESS);
            roulette = await Roulette.new(treasury.address, 4000);

            // Add game and fund it
            await treasury.addGame(roulette.address, "Roulette", 2000, true, { from: owner });
            await token.approve(treasury.address, 1e7);
            await treasury.addFunds(0, 1e7, "MANA", {
                from: owner
            });

            // Prepare user1
            await token.transfer(user1, 1e5);
            await token.approve(treasury.address, 1e5, {
                from: user1
            });

            await treasury.setTail(HASH_CHAIN[0], { from: owner });
        });

        it("user should get correct winning tokens", async () => {
            let beforeBetUser,
                afterBetUser,
                totalBet = 0,
                winTotal = 0;
            beforeBetUser = await token.balanceOf(user1);

            for (let i = 0; i < 4; i++) {
                totalBet += betAmounts.reduce((a, b) => a + b);
                await advanceTimeAndBlock(60);
                await roulette.play(
                    [user1, user1, user1, user1, user1],
                    1,
                    2,
                    betTypes,
                    betValues,
                    betAmounts,
                    HASH_CHAIN[i + 1],
                    "MANA",
                    { from: owner }
                );

                const { _winAmounts } = await getLastEvent("GameResult", roulette);

                console.log(
                    `     Play ${i + 1}: WinAmounts:[${_winAmounts}]`.cyan.inverse
                );

                winTotal = _winAmounts.reduce((a, b) => Number(a) + Number(b));
                // If there is a win stop
                if (winTotal > 0) {
                    winAmounts = _winAmounts;
                    break;
                }
            }
            afterBetUser = await token.balanceOf(user1);

            // AfterBalance = InitialBalance - amountBet + AmountWin
            assert.equal(
                afterBetUser.toNumber(),
                beforeBetUser.toNumber() + Number(winTotal) - totalBet
            );
        });

        it("correct game token balance after win", async () => {
            let beforeBetGame,
                afterBetGame,
                amountWin,
                totalBet = 0,
                winTotal = 0;

            beforeBetGame = await treasury.checkAllocatedTokensPerGame(0, "MANA");

            for (let i = 0; i < 4; i++) {
                totalBet += betAmounts.reduce((a, b) => a + b);

                await advanceTimeAndBlock(60);
                await roulette.play(
                    [user1, user1, user1, user1, user1],
                    1,
                    2,
                    betTypes,
                    betValues,
                    betAmounts,
                    HASH_CHAIN[i + 1],
                    "MANA",
                    { from: owner }
                );

                const { _winAmounts } = await getLastEvent("GameResult", roulette);

                console.log(
                    `     Play ${i + 1}: WinAmounts:[${_winAmounts}]`.cyan.inverse
                );

                winTotal = _winAmounts.reduce((a, b) => Number(a) + Number(b));
                // If there is a win stop
                if (winTotal > 0) {
                    winAmounts = _winAmounts;
                    break;
                }
            }

            afterBetGame = await treasury.checkAllocatedTokensPerGame(0, "MANA");

            assert.equal(
                afterBetGame.toNumber(),
                beforeBetGame.toNumber() + totalBet - Number(winTotal)
            );
        });
    });

    describe("Game Play: Slots", () => {
        const betTypes = [0];
        const betValues = [0];
        const betAmounts = [500];

        beforeEach(async () => {
            token = await Token.new();
            treasury = await Treasury.new(token.address, "MANA", ZERO_ADDRESS);
            slots = await Slots.new(treasury.address, 250, 16, 8, 4, 100000000);
            await treasury.addGame(slots.address, "Slots", 1000, true, { from: owner });
            await token.approve(treasury.address, web3.utils.toWei("100"));
            await treasury.addFunds(0, web3.utils.toWei("100"), "MANA", {
                from: owner
            });
            await token.transfer(user1, 10000);
            await token.approve(treasury.address, 5000, { from: user1 });

            await treasury.setTail(HASH_CHAIN[0], { from: owner });
        });

        it("should revert if exceeds maximum amount of game bet", async () => {
            await catchRevert(
                slots.play(
                    [user1],
                    1,
                    2,
                    [0],
                    [0],
                    [2000],
                    HASH_CHAIN[1],
                    "MANA",
                    { from: owner }
                ),
                "revert bet amount is more than maximum"
            );
        });

        it("should be able to play slots", async () => {
            await advanceTimeAndBlock(60);
            await slots.play(
                [user1],
                0,
                100,
                [0],
                [0],
                [100],
                HASH_CHAIN[1],
                "MANA",
                { from: owner }
            );
        });

        it("should emit a GameResult event with correct details", async () => {
            await token.approve(treasury.address, 5000, { from: user1 });
            await advanceTimeAndBlock(60);
            await slots.play(
                [user1],
                1,
                2,
                [0],
                [0],
                [100],
                HASH_CHAIN[1],
                "MANA",
                { from: owner }
            );
            const { _players, _tokenName, _landID, _machineID } = await getLastEvent(
                "GameResult",
                slots
            );
            assert.equal(JSON.stringify(_players), JSON.stringify([user1]));
            assert.equal(_tokenName, "0x4605d046b0132734b6fc45e75049e1422f8ec9d9cdeec93f928bdb57662cecdc");
            assert.equal(_landID, 1);
            assert.equal(_machineID, 2);
        });
    });

    describe("Game Results: Slots", () => {
        const betTypes = [0];
        const betValues = [0];
        const betAmounts = [500];

        beforeEach(async () => {
            // Deploy contracts
            token = await Token.new();
            treasury = await Treasury.new(token.address, "MANA", ZERO_ADDRESS);
            slots = await Slots.new(treasury.address, 250, 16, 8, 4, 1000000000000000);

            // Add game and fund it
            await treasury.addGame(slots.address, "Slots", 2000, true, { from: owner });
            await token.approve(treasury.address, 1e7);
            await treasury.addFunds(0, 1e7, "MANA", {
                from: owner
            });

            // Prepare user1
            await token.transfer(user1, 1e5);
            await token.approve(treasury.address, 1e5, {
                from: user1
            });

            await treasury.setTail(
                "0x7f7e3e79bc27e06158e71e3d1ad06c358ac9634e29875cd95c3041e0206494d5",
                { from: owner }
            );
        });

        it("user should get correct winning tokens", async () => {
            let beforeBetUser,
                afterBetUser,
                totalBet = 0,
                winTotal = 0;

            beforeBetUser = await token.balanceOf(user1);

            for (let i = 0; i < 5; i++) {
                totalBet += 500;
                await advanceTimeAndBlock(60);
                await slots.play(
                    [user1],
                    0,
                    100,
                    betTypes,
                    betValues,
                    betAmounts,
                    HASH_CHAIN[i + 1],
                    "MANA",
                    { from: owner }
                );

                const { _winAmounts } = await getLastEvent("GameResult", slots);

                console.log(
                    `     Play ${i + 1}: WinAmounts:[${_winAmounts}]`.cyan.inverse
                );

                winTotal = _winAmounts.reduce((a, b) => Number(a) + Number(b));
                // If there is a win stop
                if (winTotal > 0) {
                    winAmounts = _winAmounts;
                    break;
                }
            }

            afterBetUser = await token.balanceOf(user1);

            assert.equal(
                afterBetUser.toNumber(),
                beforeBetUser.toNumber() + Number(winTotal) - totalBet
            );
        });

        it("correct game token balance after win", async () => {
            let beforeBetGame,
                afterBetGame,
                totalBet = 0,
                winTotal = 0;

            beforeBetGame = await treasury.checkAllocatedTokensPerGame(0, "MANA");

            for (let i = 0; i < 50; i++) {
                totalBet += 500;
                await advanceTimeAndBlock(60);
                await slots.play(
                    [user1],
                    0,
                    2,
                    betTypes,
                    betValues,
                    betAmounts,
                    HASH_CHAIN[i + 1],
                    "MANA",
                    { from: owner }
                );

                const { _winAmounts } = await getLastEvent("GameResult", slots);

                console.log(
                    `    Play ${i + 1}: WinAmounts:[${_winAmounts}]`.cyan.inverse
                );

                winTotal = _winAmounts.reduce((a, b) => Number(a) + Number(b));
                // If there is a win stop
                if (winTotal > 0) {
                    winAmounts = _winAmounts;
                    break;
                }
            }

            afterBetGame = await treasury.checkAllocatedTokensPerGame(0, "MANA");

            assert.equal(
                afterBetGame.toNumber(),
                beforeBetGame.toNumber() + totalBet - winTotal
            );
        });
    });

    describe("Game Play: Roulette Special Cases", () => {
        const players = [
            user1,
            user1,
            user1,
            user1,
            user1,
            user1,
            user1,
            user1,
            user1,
            user1,
            user2,
            user2,
            user2,
            user2,
            user2,
            user2,
            user2,
            user2,
            user2,
            user2,
            user2,
            user2,
            user2,
            user2,
            user2,
            user2,
            user2,
            user2,
            user2,
            user2
        ];
        const betTypes = new Array(30).fill(0);
        const betValues = [
            5,14,15,20,21,24,26,27,30,36,1,2,4,7,8,10,
            11,13,16,17,19,22,23,25,28,29,31,32,34,35
        ];
        const betAmount = [
            '1000000000000000000000',
            '1000000000000000000000',
            '1000000000000000000000',
            '1000000000000000000000',
            '1000000000000000000000',
            '1000000000000000000000',
            '1000000000000000000000',
            '1000000000000000000000',
            '1000000000000000000000',
            '1000000000000000000000',
            '50000000000000000000',
            '50000000000000000000',
            '50000000000000000000',
            '50000000000000000000',
            '50000000000000000000',
            '50000000000000000000',
            '50000000000000000000',
            '50000000000000000000',
            '50000000000000000000',
            '50000000000000000000',
            '50000000000000000000',
            '50000000000000000000',
            '50000000000000000000',
            '50000000000000000000',
            '50000000000000000000',
            '50000000000000000000',
            '50000000000000000000',
            '50000000000000000000',
            '50000000000000000000',
            '50000000000000000000'
        ];

        beforeEach(async () => {
            token = await Token.new();
            treasury = await Treasury.new(token.address, "MANA", ZERO_ADDRESS);
            roulette = await Roulette.new(treasury.address, web3.utils.toWei("400000"));
            await treasury.addGame(roulette.address, "Roulette", web3.utils.toWei("4000"), true, { from: owner });
            await token.approve(treasury.address, web3.utils.toWei("100000000"));
            await treasury.addFunds(0, web3.utils.toWei("1000000"), "MANA", {
                from: owner
            });
            await token.transfer(user1, web3.utils.toWei("1000000000"));
            await token.transfer(user2, web3.utils.toWei("1000000000"));
            await token.transfer(user3, web3.utils.toWei("1000000000"));
            await treasury.setTail(
                "0x7f7e3e79bc27e06158e71e3d1ad06c358ac9634e29875cd95c3041e0206494d5",
                { from: owner }
            );
        });

        it("only CEO can set tail", async () => {
            await catchRevert(
                treasury.setTail(
                    "0xd1f07819ba177c9c9977dade4370f99942f8a5e24ea36750207d890293c7866f",
                    { from: random }
                )
            );
            await treasury.setTail(
                "0xd1f07819ba177c9c9977dade4370f99942f8a5e24ea36750207d890293c7866f",
                { from: owner }
            );
        });

        it("should be able to play game (30 bets)", async () => {
            await token.approve(treasury.address, web3.utils.toWei("100000000"), { from: user1 });
            await token.approve(treasury.address, web3.utils.toWei("100000000"), { from: user2 });
            await token.approve(treasury.address, web3.utils.toWei("100000000"), { from: user3 });
            await advanceTimeAndBlock(60);

            await treasury.setTail(
                "0x7f7e3e79bc27e06158e71e3d1ad06c358ac9634e29875cd95c3041e0206494d5",
                { from: owner }
            );

            await roulette.play(
                players,
                3,
                10,
                betTypes,
                betValues,
                betAmount,
                "0xd3ea1389b1549688059ed3bb1c8d9fe972389e621d1341ec4340dc468fd5576d",
                "MANA",
                { from: owner }
            );
        });

        it("should be able to play game (31 bets)", async () => {
            await token.approve(treasury.address, web3.utils.toWei("10000000000000"), { from: user1 });
            await token.approve(treasury.address, web3.utils.toWei("10000000000000"), { from: user2 });
            await token.approve(treasury.address, web3.utils.toWei("10000000000000"), { from: user3 });
            await advanceTimeAndBlock(60);
            await treasury.setTail(
                "0x7f7e3e79bc27e06158e71e3d1ad06c358ac9634e29875cd95c3041e0206494d5",
                { from: owner }
            );
            await roulette.play(
                new Array(31).fill(user2),
                3,
                20110003002006,
                new Array(31).fill(0),
                [
                    1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,
                    18,19,20,21,22,23,25,26,28,29,31,32,34,35
                ],
                new Array(31).fill('50000000000000000000'),
                "0xd3ea1389b1549688059ed3bb1c8d9fe972389e621d1341ec4340dc468fd5576d",
                "MANA",
                { from: owner }
            );
        });
    });

    describe("Migrating Treasury", () => {
        beforeEach(async () => {
            token = await Token.new();
            currentTreasury = await Treasury.new(token.address, "MANA", ZERO_ADDRESS);
            roulette = await Roulette.new(currentTreasury.address, 4000);
            slots = await Slots.new(currentTreasury.address, 250, 16, 8, 4, 1000000);
            await currentTreasury.addGame(slots.address, "Slots", 100, true, { from: owner });
            await currentTreasury.addGame(roulette.address, "Roulette", 200, true, { from: owner });

            await token.approve(currentTreasury.address, 1000000);
            await currentTreasury.addFunds(0, 1000, "MANA", { from: owner });
            await currentTreasury.addFunds(1, 2000, "MANA", { from: owner });
        });

        it("should allow to create treasury with migration address", async () => {
            newTreasury = await Treasury.new(token.address, "MANA", currentTreasury.address);
            const ceo = await newTreasury.ceoAddress();
            assert.equal(ceo, currentTreasury.address);
        });

        it("should allow only for CEO to migrate currentTreasury", async () => {
            newTreasury = await Treasury.new(token.address, "MANA", currentTreasury.address);
            await catchRevert(
                currentTreasury.migrateTreasury(newTreasury.address, { from: random })
            );
            await currentTreasury.migrateTreasury(newTreasury.address, { from: owner })
        });

        it("should be able to migrate all tokens", async () => {
            const currentTreasuryBalance = await token.balanceOf(currentTreasury.address);
            assert.equal(currentTreasuryBalance, 3000);

            newTreasury = await Treasury.new(token.address, "MANA", currentTreasury.address);
            const newTreasuryBalanceBefore = await token.balanceOf(newTreasury.address);
            assert.equal(newTreasuryBalanceBefore, 0);

            currentTreasury.migrateTreasury(newTreasury.address, { from: owner })
            const newTreasuryBalance = await token.balanceOf(newTreasury.address);
            const oldTreasuryBalance = await token.balanceOf(currentTreasury.address);
            assert.equal(newTreasuryBalance.toNumber(), currentTreasuryBalance.toNumber());
            assert.equal(oldTreasuryBalance, 0);
        });

        it("should be able to migrate all games and balances", async () => {
            const slotsInfo = await currentTreasury.games(0);
            const slotsMaxBet = await currentTreasury.gameMaximumBet(0, "MANA");
            assert.equal(slotsInfo.gameAddress, slots.address);
            assert.equal(slotsInfo.gameName, "Slots");
            assert.equal(slotsMaxBet, 100);

            const allocatedBefore = await currentTreasury.checkAllocatedTokensPerGame(0, "MANA");
            assert.equal(allocatedBefore, 1000);

            const rouletteInfo = await currentTreasury.games(1);
            const rouletteMaxBet = await currentTreasury.gameMaximumBet(1, "MANA");
            assert.equal(rouletteInfo.gameAddress, roulette.address);
            assert.equal(rouletteInfo.gameName, "Roulette");
            assert.equal(rouletteMaxBet, 200);

            const allocatedBeforeRLT = await currentTreasury.checkAllocatedTokensPerGame(1, "MANA");
            assert.equal(allocatedBeforeRLT.toNumber(), 2000);

            // MIGRATION
            newTreasury = await Treasury.new(token.address, "MANA", currentTreasury.address);
            currentTreasury.migrateTreasury(newTreasury.address, { from: owner })

            const slotsInfoNew = await newTreasury.games(0);
            const slotsMaxBetNew = await newTreasury.gameMaximumBet(0, "MANA");
            assert.equal(slotsInfoNew.gameAddress, slotsInfo.gameAddress);
            assert.equal(slotsInfoNew.gameName, slotsInfo.gameName);
            assert.equal(slotsMaxBetNew.toNumber(), slotsMaxBet.toNumber());

            const allocatedAfter = await currentTreasury.checkAllocatedTokensPerGame(0, "MANA");
            assert.equal(allocatedAfter, 0);

            const allocatedAfterToNew = await newTreasury.checkAllocatedTokensPerGame(0, "MANA");
            assert.equal(allocatedAfterToNew, 1000);
            assert.equal(allocatedAfterToNew.toNumber(), allocatedBefore.toNumber());

            const rouletteInfoNew = await newTreasury.games(1);
            const rouletteMaxBetNew = await newTreasury.gameMaximumBet(1, "MANA");
            assert.equal(rouletteInfoNew.gameAddress, rouletteInfo.gameAddress);
            assert.equal(rouletteInfoNew.gameName, rouletteInfo.gameName);
            assert.equal(rouletteMaxBetNew.toNumber(), rouletteMaxBet.toNumber());

            const allocatedAfterRLT = await currentTreasury.checkAllocatedTokensPerGame(1, "MANA");
            assert.equal(allocatedAfterRLT, 0);

            const allocatedAfterRLTNew = await newTreasury.checkAllocatedTokensPerGame(1, "MANA");
            assert.equal(allocatedAfterRLTNew.toNumber(), 2000);
            assert.equal(allocatedAfterRLTNew.toNumber(), allocatedBeforeRLT.toNumber());
        });

        it("should be able to migrate hashTail", async () => {
            const tail = "0x7f7e3e79bc27e06158e71e3d1ad06c358ac9634e29875cd95c3041e0206494d5";
            await currentTreasury.setTail(
                tail,
                { from: owner }
            );
            const currentTreasuryTail = await currentTreasury.tail();
            assert.equal(currentTreasuryTail, tail);

            newTreasury = await Treasury.new(token.address, "MANA", currentTreasury.address);
            currentTreasury.migrateTreasury(newTreasury.address, { from: owner })

            const newTreasuryTail = await newTreasury.tail();
            assert.equal(newTreasuryTail, tail);
            assert.equal(newTreasuryTail, currentTreasuryTail);
        });
    });
});
