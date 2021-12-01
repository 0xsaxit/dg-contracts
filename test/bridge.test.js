const DGToken = artifacts.require("dgToken");
const DGLightToken = artifacts.require("DGLight");
const DGLightBridge = artifacts.require("DGLightBridge");
const catchRevert = require("./exceptionsHelpers.js").catchRevert;

require("./utils");

const _BN = web3.utils.BN;
const BN = (value) => {
    return new _BN(value)
}

// TESTING PARAMETERS
const ONE_TOKEN = web3.utils.toWei("1");
const THREE_ETH = web3.utils.toWei("3");
const FIVE_ETH = web3.utils.toWei("5");
const STATIC_SUPPLY = web3.utils.toWei("5000000");
const RATIO = BN(1000);

const testAmounts = [
    "0",
    "1",
    "5",
    "20",
    "50",
    "100",
    "1000",
    "2865",
    "27891",
    "88964",
    "775680",
];

const getLastEvent = async (eventName, instance) => {
    const events = await instance.getPastEvents(eventName, {
        fromBlock: 0,
        toBlock: "latest",
    });

    return events.pop().returnValues;
};

contract("DGLightBridge", ([owner, alice, bob, random]) => {

    let dgLightToken;
    let dgToken;
    let dgLightBridge;

    beforeEach(async () => {
        dgToken = await DGToken.new();
        dgLightToken = await DGLightToken.new(dgToken.address);
        dgLightBridge = await DGLightBridge.new(dgToken.address, dgLightToken.address);

        await dgToken.approve(dgLightToken.address, STATIC_SUPPLY);
        await dgLightToken.goLight(STATIC_SUPPLY);
    });

    describe("SponsorLight Functionality", () => {

        it("should revert if there is no approval when using sponsorLight", async () => {

            await catchRevert(
                dgLightBridge.sponsorLight(
                    ONE_TOKEN
                )
            );
        });

        it("should revert if the sender has spent more than their approved amount when using sponsorLight", async () => {
        
            const approvedValue = ONE_TOKEN;
            const sponsoredValue = THREE_ETH;

            await dgLightToken.approve(
                dgLightBridge.address,
                approvedValue
            );
            await catchRevert(
                dgLightBridge.sponsorLight(
                    sponsoredValue
                )
            );
        });

        it("should revert if not enough balance in the wallet", async () => {

            const balanceBefore = await dgLightToken.balanceOf(owner);
            const swapValue = balanceBefore.addn(1).toString();

            await dgLightToken.approve(
                dgLightBridge.address,
                swapValue
            );
            await catchRevert(
                dgLightBridge.sponsorLight(
                    swapValue
                )
            );
        });

        it("should sponsor correct amount of DGLightToken", async () => {
            const sponsoredValue = FIVE_ETH;

            const sponsorBalanceBefore = await dgLightBridge.sponsors(owner);
            const ownerBalanceBefore = await dgLightToken.balanceOf(owner);

            await dgLightToken.approve(
                dgLightBridge.address,
                sponsoredValue
            );
            await dgLightBridge.sponsorLight(
                sponsoredValue
            );

            const sponsorBalanceAfter = await dgLightBridge.sponsors(owner);
            const ownerBalanceAfter = await dgLightToken.balanceOf(owner);

            assert.equal(
                sponsorBalanceAfter.toString(),
                sponsorBalanceBefore.add(BN(sponsoredValue)).toString()
            );
            assert.equal(
                ownerBalanceAfter.toString(),
                ownerBalanceBefore.sub(BN(sponsoredValue)).toString()
            );
        });
    });

    describe("SponsorClassic Functionality", () => {

        it("should revert if there is no approval when using sponsorClassic", async () => {

            await catchRevert(
                dgLightBridge.sponsorClassic(
                    ONE_TOKEN
                )
            );
        });

        it("should revert if the sender has spent more than their approved amount when using sponsorClassic", async () => {
        
            const approvedValue = ONE_TOKEN;
            const sponsoredValue = THREE_ETH;

            await dgToken.approve(
                dgLightBridge.address,
                approvedValue
            );
            await catchRevert(
                dgLightBridge.sponsorClassic(
                    sponsoredValue
                )
            );
        });

        it("should revert if not enough balance in the wallet", async () => {

            const balanceBefore = await dgToken.balanceOf(owner);
            const swapValue = balanceBefore.addn(1).toString();

            await dgToken.approve(
                dgLightBridge.address,
                swapValue
            );
            await catchRevert(
                dgLightBridge.sponsorClassic(
                    swapValue
                )
            );
        });

        it("should sponsor correct amount of DGToken", async () => {
            const sponsoredValue = FIVE_ETH;

            const sponsorBalanceBefore = await dgLightBridge.sponsors(owner);
            const ownerBalanceBefore = await dgToken.balanceOf(owner);

            await dgToken.approve(
                dgLightBridge.address,
                sponsoredValue
            );
            await dgLightBridge.sponsorClassic(
                sponsoredValue
            );

            const sponsorBalanceAfter = await dgLightBridge.sponsors(owner);
            const ownerBalanceAfter = await dgToken.balanceOf(owner);

            assert.equal(
                sponsorBalanceAfter.toString(),
                sponsorBalanceBefore.add(BN(sponsoredValue).mul(RATIO)).toString()
            );
            assert.equal(
                ownerBalanceAfter.toString(),
                ownerBalanceBefore.sub(BN(sponsoredValue)).toString()
            );
        });
    });

    describe("RedeemLight Functionality", () => {

        beforeEach(async () => {
            const sponsoredValue = FIVE_ETH;

            await dgLightToken.approve(
                dgLightBridge.address,
                sponsoredValue
            );
            await dgLightBridge.sponsorLight(
                sponsoredValue
            );
        });

        it("should revert if not enough balance in the DGLightBridge", async () => {

            const balanceBefore = await dgLightBridge.sponsors(owner);

            await catchRevert(
                dgLightBridge.redeemLight(
                    balanceBefore.addn(1).toString()
                )
            );
        });

        it("should sponsor correct amount of DGLightToken", async () => {
            const sponsoredValue = FIVE_ETH;

            const sponsorBalanceBefore = await dgLightBridge.sponsors(owner);
            const ownerBalanceBefore = await dgLightToken.balanceOf(owner);

            await dgLightBridge.redeemLight(
                sponsoredValue
            );

            const sponsorBalanceAfter = await dgLightBridge.sponsors(owner);
            const ownerBalanceAfter = await dgLightToken.balanceOf(owner);

            assert.equal(
                sponsorBalanceAfter.toString(),
                sponsorBalanceBefore.sub(BN(sponsoredValue)).toString()
            );
            assert.equal(
                ownerBalanceAfter.toString(),
                ownerBalanceBefore.add(BN(sponsoredValue)).toString()
            );
        });
    });
    
    describe("RedeemClassic Functionality", () => {

        beforeEach(async () => {
            const sponsoredValue = FIVE_ETH;

            await dgToken.approve(dgLightBridge.address, sponsoredValue);
            await dgLightBridge.sponsorClassic(
                sponsoredValue
            );
        });

        it("should revert if not enough balance in the DGLightBridge", async () => {

            const balanceBefore = await dgLightBridge.sponsors(owner);

            await catchRevert(
                dgLightBridge.redeemLight(
                    balanceBefore.div(RATIO).addn(1).toString()
                )
            );
        });

        it("should sponsor correct amount of DGToken", async () => {
            const sponsoredValue = FIVE_ETH;

            const sponsorBalanceBefore = await dgLightBridge.sponsors(owner);
            const ownerBalanceBefore = await dgToken.balanceOf(owner);

            await dgLightBridge.redeemClassic(
                sponsoredValue
            );

            const sponsorBalanceAfter = await dgLightBridge.sponsors(owner);
            const ownerBalanceAfter = await dgToken.balanceOf(owner);

            assert.equal(
                sponsorBalanceAfter.toString(),
                sponsorBalanceBefore.sub(BN(sponsoredValue).mul(RATIO)).toString()
            );
            assert.equal(
                ownerBalanceAfter.toString(),
                ownerBalanceBefore.add(BN(sponsoredValue)).toString()
            );
        });
    });

    describe("GoLight Functionality", () => {

        it("should revert if there is no approval when using goLight", async () => {

            const sponsoredValue = BN(STATIC_SUPPLY).mul(RATIO).toString();

            await dgLightToken.approve(
                dgLightBridge.address,
                sponsoredValue
            );
            await dgLightBridge.sponsorLight(
                sponsoredValue
            );
            await catchRevert(
                dgLightBridge.goLight(
                    ONE_TOKEN
                )
            );
        });

        it("should revert if the sender has spent more than their approved amount when using goLight", async () => {
        
            const sponsoredValue = BN(STATIC_SUPPLY).mul(RATIO).toString();
            const approvedValue = ONE_TOKEN;
            const swapValue = THREE_ETH;

            await dgLightToken.approve(
                dgLightBridge.address,
                sponsoredValue
            );
            await dgLightBridge.sponsorLight(
                sponsoredValue
            );
            await dgToken.approve(
                dgLightBridge.address,
                approvedValue
            );
            await catchRevert(
                dgLightBridge.goLight(
                    swapValue
                )
            );
        });

        it("should revert if not enough balance in the DGLightBridge", async () => {

            const approvedValue = ONE_TOKEN;
            const swapValue = THREE_ETH;

            await dgToken.approve(
                dgLightBridge.address,
                approvedValue
            );
            await catchRevert(
                dgLightBridge.goLight(
                    swapValue
                )
            );
        });

        it("should revert if not enough balance in the wallet", async () => {

            const balanceBefore = await dgToken.balanceOf(owner);
            const swapValue = balanceBefore.addn(1).toString();

            await dgToken.approve(
                dgLightBridge.address,
                swapValue
            );
            await catchRevert(
                dgLightBridge.goLight(
                    swapValue
                )
            );
        });

        it("should swap correct amount from DGToken to DGLightToken", async () => {

            const sponsoredValue = BN(STATIC_SUPPLY).mul(RATIO).toString();

            await dgLightToken.approve(
                dgLightBridge.address,
                sponsoredValue
            );
            await dgLightBridge.sponsorLight(
                sponsoredValue
            );

            for (let i = 0; i < testAmounts.length; i += 1) {
                const swapValue = web3.utils.toWei(testAmounts[i]);

                const dgBalanceBefore = await dgToken.balanceOf(owner);
                const balanceBefore = await dgLightToken.balanceOf(owner);

                await dgToken.approve(
                    dgLightBridge.address,
                    swapValue
                );
                await dgLightBridge.goLight(
                    swapValue
                );

                const dgBalanceAfter = await dgToken.balanceOf(owner);
                const balanceAfter = await dgLightToken.balanceOf(owner);

                assert.equal(
                    dgBalanceAfter.toString(),
                    dgBalanceBefore.sub(BN(swapValue)).toString()
                );
                assert.equal(
                    balanceAfter.toString(),
                    balanceBefore.add(BN(swapValue).mul(RATIO)).toString()
                );
            }
        });
    });

    describe("GoClassic Functionality", () => {

        it("should revert if there is no approval when using goClassic", async () => {

            const sponsoredValue = STATIC_SUPPLY;

            await dgToken.approve(
                dgLightBridge.address,
                sponsoredValue
            );
            await dgLightBridge.sponsorClassic(
                sponsoredValue
            );
            await catchRevert(
                dgLightBridge.goClassic(
                    ONE_TOKEN
                )
            );
        });

        it("should revert if the sender has spent more than their approved amount when using goClassic", async () => {
        
            const sponsoredValue = STATIC_SUPPLY;
            const approvedValue = ONE_TOKEN;
            const swapValue = THREE_ETH;

            await dgToken.approve(
                dgLightBridge.address,
                sponsoredValue
            );
            await dgLightBridge.sponsorClassic(
                sponsoredValue
            );
            await dgLightToken.approve(
                dgLightBridge.address,
                approvedValue
            );
            await catchRevert(
                dgLightBridge.goClassic(
                    swapValue
                )
            );
        });

        it("should revert if not enough balance in the DGLightBridge", async () => {

            const approvedValue = ONE_TOKEN;
            const swapValue = THREE_ETH;

            await dgLightToken.approve(
                dgLightBridge.address,
                approvedValue
            );
            await catchRevert(
                dgLightBridge.goClassic(
                    swapValue
                )
            );
        });

        it("should revert if not enough balance in the wallet", async () => {

            const balanceBefore = await dgToken.balanceOf(owner);
            const swapValue = balanceBefore.addn(1).toString();

            await dgLightToken.approve(
                dgLightBridge.address,
                swapValue
            );
            await catchRevert(
                dgLightBridge.goClassic(
                    swapValue
                )
            );
        });

        it("should swap correct amount from DGLightToken to DGToken", async () => {

            const sponsoredValue = BN(STATIC_SUPPLY).mul(RATIO).toString();

            await dgToken.approve(
                dgLightBridge.address,
                sponsoredValue
            );
            await dgLightBridge.sponsorClassic(
                sponsoredValue
            );

            for (let i = 0; i < testAmounts.length; i += 1) {
                const swapValue = web3.utils.toWei(testAmounts[i]);

                const dgBalanceBefore = await dgToken.balanceOf(owner);
                const balanceBefore = await dgLightToken.balanceOf(owner);

                await dgLightToken.approve(
                    dgLightBridge.address,
                    BN(swapValue).mul(RATIO).toString()
                );
                await dgLightBridge.goClassic(
                    swapValue
                );

                const dgBalanceAfter = await dgToken.balanceOf(owner);
                const balanceAfter = await dgLightToken.balanceOf(owner);

                assert.equal(
                    dgBalanceAfter.toString(),
                    dgBalanceBefore.sub(BN(swapValue)).toString()
                );
                assert.equal(
                    balanceAfter.toString(),
                    balanceBefore.add(BN(swapValue).mul(RATIO)).toString()
                );
            }
        });
    });
});
