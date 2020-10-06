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

            await catchRevert(pointer.distributeTokens(user1));
        });

        it("should ONLY allow worker to assign affiliate", async () => {

            const affiliatedUser = user1;
            const affiliatingUser = user2;
            const workerUser = owner;

            await catchRevert(
                pointer.assignAffiliate(affiliatedUser, affiliatingUser, { from: random })
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

            await catchRevert(pointer.changeDistributionToken(token.address, { from: random }));
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

            await catchRevert(pointer.distributeTokens(user1));

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


});
