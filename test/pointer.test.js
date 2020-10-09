const Token = artifacts.require("dgToken");
const Pointer = artifacts.require("dgPointer");
const Slots = artifacts.require("dgSlots");
const Treasury = artifacts.require("dgTreasury");
const catchRevert = require("./exceptionsHelpers.js").catchRevert;
const positions = [0, 16, 32, 48];
const name = "name";
const version = "0";

require("./utils");

const getLastEvent = async (eventName, instance) => {
    const events = await instance.getPastEvents(eventName, {
        fromBlock: 0,
        toBlock: "latest"
    });
    return events.pop().returnValues;
};

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

contract("dgPointer", ([owner, user1, user2, random]) => {
    let slots;
    before(async () => {
        token = await Token.new();
        pointer = await Pointer.new(token.address, name, version);
        slots = await Slots.new(owner, 250, 15, 8, 4, pointer.address, {from: owner});
        pointer.declareContract(owner);
        // pointer.setPointToTokenRatio(100);
        // pointer.enableCollecting(true);
    });

    describe("Initial Variables", () => {

        beforeEach(async () => {
            token = await Token.new();
            pointer = await Pointer.new(token.address, name, version);
            pointer.declareContract(owner);
        });

        it("should have correct distributionToken address", async () => {
            const distributionToken = await pointer.distributionToken();
            assert.equal(distributionToken, token.address);
        });

        it("should allow to declare contract", async () => {
            const resultBeforeDeclare = await pointer.declaredContracts(slots.address);
            await pointer.declareContract(slots.address);
            const resultAfterDeclare = await pointer.declaredContracts(slots.address);
            assert.equal(resultBeforeDeclare, false);
            assert.equal(resultAfterDeclare, true);
        });

        it("should allow to set tokenToPointsRatio", async () => {
            const resultBefore = await pointer.tokenToPointRatio(token.address);
            await pointer.setPointToTokenRatio(token.address, 150);
            const resultAfter = await pointer.tokenToPointRatio(token.address);
            assert.equal(resultBefore, 0);
            assert.equal(resultAfter, 150);
        });

        it("should NOT allow to set points from undeclared address", async () => {
            const ratio = 150;
            const points = 15000;
            const resultBefore = await pointer.pointsBalancer(user1);
            await pointer.enableCollecting(true);
            await pointer.declareContract(user2);
            await pointer.setPointToTokenRatio(token.address, ratio);
            await pointer.addPoints(user1, points, token.address, 1, 0, {from: user1});
            const resultAfter = await pointer.pointsBalancer(user1);

            assert.equal(resultBefore, 0);
            assert.equal(resultAfter, 0);
        });

        //currently fails
        //checks that addPoints --> 0 when enabledCollecting = FALSE, checks defaulting to FALSE
        it("should allow to set points from declared address", async () => {
            const ratio = 150;
            const points = 15000;
            //check is 0 at first
            const resultBefore = await pointer.pointsBalancer(user1);

            //declare contract, enable collecting defaults to true
            await pointer.declareContract(user2);
            await pointer.setPointToTokenRatio(token.address, ratio);
            await pointer.addPoints(user1, points, token.address, 1, 0, {from: user2});
            const resultAfterDefault = await pointer.pointsBalancer(user1);

            //enable collecting
            await pointer.enableCollecting(false);
            await pointer.addPoints(user2, points, token.address, 1, 0, {from: user2});
            const resultAfterDisabled = await pointer.pointsBalancer(user2);

            await pointer.enableCollecting(true);
            await pointer.addPoints(random, points, token.address, 1, 0, {from: user2});
            const resultAfterEnabled = await pointer.pointsBalancer(random);

            assert.equal(resultBefore, 0);
            assert.equal(resultAfterDefault, 0);
            assert.equal(resultAfterDisabled, 0);
            assert.equal(resultAfterEnabled, points/ratio);
        });

        it("should block distributionToken if bool is false", async () => {
            const ratio = 150;
            const points = 15000;
            //check user1 pointsbalancer = 0 at first
            const resultBefore = await pointer.pointsBalancer(user1);

            //collectingEnabled = true, dsitributionEnabled = false
            await pointer.enableDistribtion(false);
            await pointer.enableCollecting(true);
            await pointer.declareContract(user2);
            await pointer.setPointToTokenRatio(token.address, ratio);
            await pointer.addPoints(user1, points, token.address, 1, 0, {from: user2});

            await catchRevert(
                pointer.distributeTokens(
                    user1
                ),
                'revert Pointer: distribution disabled'
            );

        });

        it("should ONLY allow worker to assign affiliate", async () => {

            const affiliatedUser = user1;
            const affiliatingUser = user2;
            const workerUser = owner;

            await catchRevert(
                pointer.assignAffiliate(
                    affiliatedUser,
                    affiliatingUser,
                    { from: random }
                ),
                'revert AccessControl: worker access denied'
            );


            await pointer.setWorker(workerUser, { from: owner });
            const event = await getLastEvent("WorkerSet", pointer);
            assert.equal(event.newWorker, workerUser);

            await pointer.assignAffiliate(affiliatedUser, affiliatingUser, { from: workerUser });
            const affiliateAddress = await pointer.affiliateData(affiliatingUser);

            assert.equal(affiliateAddress, affiliatedUser);
        });

        it("should ONLY allow CEO to change distributionToken address", async () => {
            const distributionToken = await pointer.distributionToken();
            assert.equal(distributionToken, token.address);

            await catchRevert(
                pointer.changeDistributionToken(
                    token.address,
                    { from: random }
                ),
                'revert AccessControl: CEO access denied'
            );

            await pointer.changeDistributionToken(token.address, { from: owner });
        });

        it("should block distributionToken if bool is false", async () => {

            await token.transfer(pointer.address, 100000);

            const event = await getLastEvent("Transfer", token);
            assert.equal(event.to, pointer.address);
            assert.equal(event.value, 100000);

            const ratio = 150;
            const points = 15000;
            const resultBefore = await pointer.pointsBalancer(user2);

            //await pointer.enableDistribtion(false);
            await pointer.enableDistribtion(false);
            await pointer.enableCollecting(true);
            await pointer.declareContract(user2);
            await pointer.setPointToTokenRatio(token.address, ratio);
            await pointer.addPoints(user1, points, token.address, 1, 0, {from: user2});
            const resultAfter = await pointer.pointsBalancer(user1);

            await catchRevert(
                pointer.distributeTokens(
                    user1
                ),
                'revert Pointer: distribution disabled'
            );

            assert.equal(resultBefore, 0);
            assert.equal(resultAfter, points/ratio);
        });

        it("should ALLOW distributionToken if bool is true", async () => {

            await token.transfer(pointer.address, 100000);
            const event = await getLastEvent("Transfer", token);
            assert.equal(event.to, pointer.address);
            assert.equal(event.value, 100000);

            const ratio = 150;
            const points = 15000;
            const resultBefore = await pointer.pointsBalancer(user1);

            await pointer.enableDistribtion(true);
            await pointer.enableCollecting(true);
            await pointer.declareContract(user2);
            await pointer.setPointToTokenRatio(token.address, ratio);
            await pointer.addPoints(user1, points, token.address, 1, 0, {from: user2});

            const resultBeforeDistributed = await pointer.pointsBalancer(user1);
            await pointer.distributeTokens(user1);
            const resultAfterDistributed = await pointer.pointsBalancer(user1);

            assert.equal(resultBefore, 0);
            assert.equal(resultBeforeDistributed, points/ratio);
            assert.equal(resultAfterDistributed, 0);
        });
    });


    describe("dgPointer functions", () => {
        /*
            it("should allow assign affiliate to add points with NFT", async () => {
            });
        */
        //getWearableMultiplier
        //enable collecting = false, check points = 0
        //admin sets enablecollecting = true, check points = expected points for that game
        //distributionEnabled = false, check points = 0
        //admin sets distributionEnabled = true, check points = expected points for that game
    });


    describe("dgPointer bonus points", () => {

        beforeEach(async () => {
            token = await Token.new();
            pointer = await Pointer.new(token.address, name, version);
            slots = await Slots.new(owner, 250, 15, 8, 4, pointer.address, {from: owner});
            pointer.declareContract(owner);
            // pointer.enableDistribtion(true);
            // pointer.enableCollecting(true);
            // pointer.declareContract(user2);
            // const ratio = 150;
            // const points = 15000;
            // pointer.setPointToTokenRatio(token.address, ratio);
            // pointer.setPointToTokenRatio(100);
        });

        it("should NOT allow 0 players", async () => {
            const points = 15000;
            await catchRevert(
                pointer.addPoints(
                    user1,
                    points,
                    token.address,
                    0, // _numPlayers
                    0, // _wearableBonus
                    {from: owner},
                ),
                'revert dgPointer: _numPlayers error'
            );
        });

        //currently fails
        it("should allow 3 params for addPoints", async () => {
            const ratio = 150;
            const points = 15000;

            const resultBefore = await pointer.pointsBalancer(user1);
            await pointer.enableDistribtion(true);
            await pointer.enableCollecting(true);
            await pointer.setPointToTokenRatio(token.address, ratio);
            await pointer.addPoints(user1, points, token.address);
            const resultAfter = await pointer.pointsBalancer(user1);

            assert.equal(resultBefore, 0);
            assert.equal(resultAfter, points/ratio);
        });

        //currently fails
        it("should allow 4 params for addPoints", async () => {
            const ratio = 150;
            const points = 15000;

            const resultBefore = await pointer.pointsBalancer(user1);
            await pointer.enableDistribtion(true);
            await pointer.enableCollecting(true);
            await pointer.setPointToTokenRatio(token.address, ratio);
            await pointer.addPoints(user1, points, token.address, 1);

            const resultAfter = await pointer.pointsBalancer(user1);

            assert.equal(resultBefore, 0);
            assert.equal(resultAfter, points/ratio);
        });

        it("should give 20% bonus for numPlayers = 2", async () => {
            const ratio = 150;
            const points = 15000;
            const bonuspoints = points + ((points*20)/100);

            //check user1 pointsbalancer = 0 at first
            const resultBefore = await pointer.pointsBalancer(user1);
            await pointer.enableDistribtion(true);
            await pointer.enableCollecting(true);
            await pointer.declareContract(user2);
            await pointer.setPointToTokenRatio(token.address, ratio);
            await pointer.addPoints(user1, points, token.address, 2, 0, {from: user2});

            const resultAfter = await pointer.pointsBalancer(user1);

            assert.equal(resultBefore, 0);
            assert.equal(resultAfter, bonuspoints/ratio);
        });

        it("should give 30% bonus for numPlayers = 3", async () => {
            const ratio = 150;
            const points = 15000;
            const bonuspoints = points + ((points * 30) / 100);

            // check user1 pointsbalancer = 0 at first
            const resultBefore = await pointer.pointsBalancer(user1);
            await pointer.enableDistribtion(true);
            await pointer.enableCollecting(true);
            await pointer.declareContract(user2);
            await pointer.setPointToTokenRatio(token.address, ratio);
            await pointer.addPoints(user1, points, token.address, 3, 0, {from: user2});

            const resultAfter = await pointer.pointsBalancer(user1);

            assert.equal(resultBefore, 0);
            assert.equal(resultAfter, bonuspoints/ratio);
        });

        it("should give 40% bonus for numPlayers = 4", async () => {
            const ratio = 150;
            const points = 15000;
            const bonuspoints = points + ((points * 40) / 100);

            // check user1 pointsbalancer = 0 at first
            const resultBefore = await pointer.pointsBalancer(user1);
            await pointer.enableDistribtion(true);
            await pointer.enableCollecting(true);
            await pointer.declareContract(user2);
            await pointer.setPointToTokenRatio(token.address, ratio);
            await pointer.addPoints(user1, points, token.address, 4, 0, {from: user2});

            const resultAfter = await pointer.pointsBalancer(user1);

            assert.equal(resultBefore, 0);
            assert.equal(resultAfter, bonuspoints/ratio);
        });

        it("should only give 4 player bonus with +4 players", async () => {
            const ratio = 150;
            const points = 15000;
            // const bonuspoints = points * 1.4;
            const bonuspoints = 21000;

            // check user1 pointsbalancer = 0 at first
            const resultBefore = await pointer.pointsBalancer(user1);
            await pointer.enableDistribtion(true);
            await pointer.enableCollecting(true);
            await pointer.declareContract(user2);
            await pointer.setPointToTokenRatio(token.address, ratio);
            await pointer.addPoints(user1, points, token.address, 10, 0, {from: user2});

            const resultAfter = await pointer.pointsBalancer(user1);

            assert.equal(resultBefore, 0);
            assert.equal(resultAfter, bonuspoints/ratio);
        });

        it("should give 10% bonus for numWearables = 1", async () => {
            const ratio = 150;
            const points = 15000;
            const bonuspoints = points + ((points * 10) / 100);

            // check user1 pointsbalancer = 0 at first
            const resultBefore = await pointer.pointsBalancer(user1);
            await pointer.enableDistribtion(true);
            await pointer.enableCollecting(true);
            await pointer.declareContract(user2);
            await pointer.setPointToTokenRatio(token.address, ratio);
            await pointer.addPoints(user1, points, token.address, 1, 1, {from: user2});

            const resultAfter = await pointer.pointsBalancer(user1);

            assert.equal(resultBefore, 0);
            assert.equal(resultAfter, bonuspoints/ratio);

            // pointer = await Pointer.new(token.address, name, version);
        });

        it("should give 20% bonus for numWearables = 2", async () => {
            const ratio = 150;
            const points = 15000;
            // const prevPoints = await pointer.pointsBalancer(user1);
            const bonuspoints = points + ((points * 20) / 100);

            // check user1 pointsbalancer = 0 at first
            const resultBefore = await pointer.pointsBalancer(user1);
            await pointer.enableDistribtion(true);
            await pointer.enableCollecting(true);
            await pointer.declareContract(user2);
            await pointer.setPointToTokenRatio(token.address, ratio);
            await pointer.addPoints(user1, points, token.address, 1, 2, {from: user2});

            const resultAfter = await pointer.pointsBalancer(user1);
            assert.equal(resultAfter, bonuspoints/ratio);
        });

        it("should give 30% bonus for numWearables = 3", async () => {
            const ratio = 150;
            const points = 15000;
            // const prevPoints = await pointer.pointsBalancer(user8);
            const bonuspoints = points + ((points * 30) / 100);

            // check user1 pointsbalancer = 0 at first
            const resultBefore = await pointer.pointsBalancer(user1);
            await pointer.enableDistribtion(true);
            await pointer.enableCollecting(true);
            await pointer.declareContract(user2);
            await pointer.setPointToTokenRatio(token.address, ratio);
            await pointer.addPoints(user1, points, token.address, 1, 3, {from: user2});

            const resultAfter = await pointer.pointsBalancer(user1);
            assert.equal(resultAfter, bonuspoints/ratio);
        });

        it("should give 40% bonus for numWearables = 4", async () => {
            const ratio = 150;
            const points = 15000;
            const bonuspoints = points + ((points * 40) / 100);

            // check user1 pointsbalancer = 0 at first
            const resultBefore = await pointer.pointsBalancer(user1);
            await pointer.enableDistribtion(true);
            await pointer.enableCollecting(true);
            await pointer.declareContract(user2);
            await pointer.setPointToTokenRatio(token.address, ratio);
            await pointer.addPoints(user1, points, token.address, 1, 4, {from: user2});

            const resultAfter = await pointer.pointsBalancer(user1);
            assert.equal(resultAfter, bonuspoints/ratio);
        });

        it("should give A MAX 40% bonus for numWearables > 4", async () => {
            const ratio = 150;
            const points = 15000;
            const bonuspoints = points + ((points * 40) / 100);

            // check user1 pointsbalancer = 0 at first
            const resultBefore = await pointer.pointsBalancer(user1);
            await pointer.enableDistribtion(true);
            await pointer.enableCollecting(true);
            await pointer.declareContract(user2);
            await pointer.setPointToTokenRatio(token.address, ratio);
            await pointer.addPoints(user1, points, token.address, 1, 10, {from: user2});

            const resultAfter = await pointer.pointsBalancer(user1);
            assert.equal(resultAfter, bonuspoints/ratio);
        });

        it("should allow to assign affiliate", async () => {
            const ratio = 150;
            const points = 15000;
            const bonus = 0.2;

            const affiliatedUser = user1;
            const affiliatingUser = user2;
            const workerUser = owner;

            // affiliate user
            await pointer.setWorker(workerUser, { from: owner });
            const event = await getLastEvent("WorkerSet", pointer);
            assert.equal(event.newWorker, workerUser);

            await pointer.assignAffiliate(affiliatedUser, affiliatingUser, { from: workerUser });
            const affiliateAddress = await pointer.affiliateData(affiliatingUser);

            assert.equal(affiliateAddress, affiliatedUser);
            await pointer.enableDistribtion(true);
            await pointer.enableCollecting(true);
            await pointer.declareContract(user2);
            await pointer.setPointToTokenRatio(token.address, ratio);
            await pointer.addPoints(affiliatingUser, points, token.address, 1, 0, {from: user2});
            const resultA = await pointer.pointsBalancer(affiliatingUser);
            const resultB = await pointer.pointsBalancer(affiliatedUser);

            assert.equal(resultA.toString(), points/ratio);
            assert.equal(resultB.toString(), (points/ratio * bonus));
        });

        // getPlayerMultiplier
        // getWearableMultiplier
    });

    describe("Game Results: Slots", () => {

        beforeEach(async () => {
            token = await Token.new();
            pointer = await Pointer.new(token.address, name, version);
            treasury = await Treasury.new(token.address, "MANA");
            slots = await Slots.new(treasury.address, 250, 16, 8, 4, pointer.address);
            pointer.declareContract(owner);
            pointer.declareContract(slots.address);
            await treasury.addGame(slots.address, "Slots", true, { from: owner });
            await treasury.setMaximumBet(0, 0, 1000, { from: owner });
            await token.approve(treasury.address, web3.utils.toWei("100"));
            await treasury.addFunds(0, 0, web3.utils.toWei("100"), {
                from: owner
            });
            await token.transfer(user1, 10000);
            await token.transfer(user2, 10000);
            await token.approve(treasury.address, 5000, { from: user1 });
            await token.approve(treasury.address, 5000, { from: user2 });
            await treasury.setTail(HASH_CHAIN[0], { from: owner });
        });

        it("should be able to play slots", async () => {
            await advanceTimeAndBlock(60);
            await slots.play(
                user1,
                1,
                2,
                100,
                HASH_CHAIN[1],
                0,
                0,
                { from: owner }
            );
        });

        it("should addPoints when playing slots", async () => {
            const resultBefore = await pointer.pointsBalancer(user1);

            //setup Pointer
            const ratio = 100;
            const betAmount = 1000;
            await pointer.enableDistribtion(true);
            await pointer.enableCollecting(true);
            await pointer.setPointToTokenRatio(token.address, ratio);

            await advanceTimeAndBlock(60);
            await slots.play(
                user1,
                1,
                2,
                betAmount,
                HASH_CHAIN[1],
                0,
                0,
                { from: owner }
            );

            const resultAfter = await pointer.pointsBalancer(user1);

            assert.equal(resultBefore, 0);
            assert.equal(resultAfter > 0 , true);
            assert.equal(resultAfter.toString(), betAmount/ratio);
        });

        it("should addPoints when playing slots continuously", async () => {
            //setup Pointer
            const ratio = 200;
            const betAmount = 1000;
            await pointer.enableDistribtion(true);
            await pointer.enableCollecting(true);
            await pointer.setPointToTokenRatio(token.address, ratio);

            let beforeBetUser,
                afterBetUser,
                totalBet = 0,
                winTotal = 0;

            beforeBetUser = await token.balanceOf(user2);
            pointsBefore = await pointer.pointsBalancer(user2);

            for (let i = 0; i < 5; i++) {
                totalBet += betAmount;
                await advanceTimeAndBlock(60);
                await slots.play(
                    user2,
                    1,
                    12,
                    betAmount,
                    HASH_CHAIN[i + 1],
                    0,
                    0,
                    { from: owner }
                );

                const { _winAmount } = await getLastEvent("GameResult", slots);

                console.log(
                    `     Play ${i + 1}: WinAmount:[${_winAmount}]`.cyan.inverse
                );

                let pointsAfter = await pointer.pointsBalancer(user2);

                console.log(
                    `     Play ${i + 1}: Points:[${pointsAfter}]`.cyan.inverse
                );

                if (_winAmount > 0) {
                    winTotal = _winAmount;
                    // break;
                }
            }

            afterBetUser = await token.balanceOf(user2);
            pointsAfter = await pointer.pointsBalancer(user2);

            assert.equal(
                afterBetUser.toNumber(),
                beforeBetUser.toNumber() + Number(winTotal) - totalBet
            );

            assert.equal(
                pointsBefore,
                0
            );

            assert.equal(
                pointsAfter > 0,
                true
            );

            assert.equal(
                pointsAfter.toString(),
                totalBet/ratio
            );
        });

        it("should addPoints when playing slots continuously (with wearables)", async () => {
            //setup Pointer
            const ratio = 200;
            const betAmount = 1000;
            const wearableCount = 4;
            const wearableBonus = 0.1;
            await pointer.enableDistribtion(true);
            await pointer.enableCollecting(true);
            await pointer.setPointToTokenRatio(token.address, ratio);

            let beforeBetUser,
                afterBetUser,
                totalBet = 0,
                winTotal = 0;

            beforeBetUser = await token.balanceOf(user2);
            pointsBefore = await pointer.pointsBalancer(user2);

            for (let i = 0; i < 5; i++) {
                totalBet += betAmount;
                await advanceTimeAndBlock(60);
                await slots.play(
                    user2,
                    1,
                    12,
                    betAmount,
                    HASH_CHAIN[i + 1],
                    0,
                    wearableCount,
                    { from: owner }
                );

                const { _winAmount } = await getLastEvent("GameResult", slots);

                console.log(
                    `     Play ${i + 1}: WinAmount:[${_winAmount}]`.cyan.inverse
                );

                let pointsAfterWithBonus = await pointer.pointsBalancer(user2);

                console.log(
                    `     Play ${i + 1}: PointsWithBonus:[${pointsAfterWithBonus}]`.cyan.inverse
                );

                if (_winAmount > 0) {
                    winTotal = _winAmount;
                    // break;
                }
            }

            pointsAfter = await pointer.pointsBalancer(user2);

            assert.equal(
                pointsAfter.toString(),
                (totalBet + (totalBet * wearableBonus * wearableCount)) / ratio
            );
        });
    });
});
