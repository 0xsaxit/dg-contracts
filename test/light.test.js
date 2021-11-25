const DGToken = artifacts.require("dgToken");
const DGLightToken = artifacts.require("DGLight");
const catchRevert = require("./exceptionsHelpers.js").catchRevert;

require("./utils");

const _BN = web3.utils.BN;
const BN = (value) => {
    return new _BN(value)
}

// TESTING PARAMETERS
const ONE_TOKEN = web3.utils.toWei("1");
const THREE_ETH = web3.utils.toWei("3");
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

contract("DGLightToken", ([owner, alice, bob, random]) => {

    let dgLightToken;
    let dgToken;

    beforeEach(async () => {
        dgToken = await DGToken.new();
        dgLightToken = await DGLightToken.new(dgToken.address);
        await dgToken.approve(dgLightToken.address, STATIC_SUPPLY);
        await dgLightToken.goLight(STATIC_SUPPLY);
    });

    describe("Token Initial Values", () => {

        it("should have correct token name", async () => {
            const name = await dgLightToken.name();
            assert.equal(
                name,
                "Decentral Games"
            );
        });

        it("should have correct token symbol", async () => {
            const symbol = await dgLightToken.symbol();
            assert.equal(
                symbol,
                "DG"
            );
        });

        it("should have correct token decimals", async () => {
            const decimals = await dgLightToken.decimals();
            assert.equal(
                decimals,
                18
            );
        });


        it("should have correct token supply", async () => {
            const supply = await dgLightToken.totalSupply();
            assert.equal(
                supply,
                BN(STATIC_SUPPLY).mul(RATIO).toString()
            );
        });

        it("should return the correct balance for the given account", async () => {
            const expectedAmount = ONE_TOKEN;

            await dgLightToken.transfer(
                bob,
                expectedAmount,
                {
                    from: owner
                }
            );

            const balance = await dgLightToken.balanceOf(bob);

            assert.equal(
                balance,
                expectedAmount
            );
        });

        it("should return the correct allowance for the given spender", async () => {
            const allowance = await dgLightToken.allowance(owner, bob);
            assert.equal(
                allowance,
                0
            );
        });
    });

    describe("Token Transfer Functionality", () => {

        it("should transfer correct amount from walletA to walletB", async () => {

            const transferValue = ONE_TOKEN;
            const balanceBefore = await dgLightToken.balanceOf(bob);

            await dgLightToken.transfer(
                bob,
                transferValue,
                {
                    from: owner
                }
            );

            const balanceAfter = await dgLightToken.balanceOf(bob);

            assert.equal(
                parseInt(balanceAfter),
                parseInt(balanceBefore) + parseInt(transferValue)
            );
        });

        it("should revert if not enough balance in the wallet", async () => {

            const balanceBefore = await dgLightToken.balanceOf(alice);

            await catchRevert(
                dgLightToken.transfer(
                    bob,
                    parseInt(balanceBefore) + 1,
                    {
                        from: alice
                    }
                )
            );
        });

        it("should reduce wallets balance after transfer", async () => {

            const transferValue = ONE_TOKEN;
            const balanceBefore = await dgLightToken.balanceOf(owner);

            await dgLightToken.transfer(
                bob,
                transferValue,
                {
                    from: owner
                }
            );

            const balanceAfter = await dgLightToken.balanceOf(owner);

            assert.equal(
                parseInt(balanceAfter),
                parseInt(balanceBefore) - parseInt(transferValue)
            );
        });

        it("should emit correct Transfer event", async () => {

            const transferValue = ONE_TOKEN;
            const expectedRecepient = bob;

            await dgLightToken.transfer(
                expectedRecepient,
                transferValue,
                {
                    from: owner
                }
            );

            const { _from: from, _to: to, _value: value } = await getLastEvent(
                "Transfer",
                dgLightToken
            );

            assert.equal(
                from,
                owner
            );

            assert.equal(
                to,
                expectedRecepient
            );

            assert.equal(
                value,
                transferValue
            );
        });

        it("should update the balance of the recipient when using transferFrom", async () => {
            const transferValue = ONE_TOKEN;
            const expectedRecipient = bob;
            const balanceBefore = await dgLightToken.balanceOf(bob);

            await dgLightToken.approve(
                owner,
                transferValue
            );

            await dgLightToken.transferFrom(
                owner,
                expectedRecipient,
                transferValue,
            );

            const balanceAfter = await dgLightToken.balanceOf(bob);

            assert.equal(
                parseInt(balanceAfter),
                parseInt(balanceBefore) + parseInt(transferValue)
            );
        });

        it("should deduct from the balance of the sender when using transferFrom", async () => {
            const transferValue = ONE_TOKEN;
            const expectedRecipient = bob;
            const balanceBefore = await dgLightToken.balanceOf(owner);

            await dgLightToken.approve(
                owner,
                transferValue
            );

            await dgLightToken.transferFrom(
                owner,
                expectedRecipient,
                transferValue,
            );

            const balanceAfter = await dgLightToken.balanceOf(owner);

            assert.equal(
                parseInt(balanceAfter),
                parseInt(balanceBefore) - parseInt(transferValue)
            );
        });

        it("should revert if there is no approval when using transferFrom", async () => {
            const transferValue = ONE_TOKEN;
            const expectedRecipient = bob;

            await catchRevert(
                dgLightToken.transferFrom(
                    owner,
                    expectedRecipient,
                    transferValue
                )
            );
        });

        it("should revert if the sender has spent more than their approved amount when using transferFrom", async () => {

            const approvedValue = ONE_TOKEN;
            const transferValue = THREE_ETH;
            const expectedRecipient = bob;

            await dgLightToken.approve(
                alice,
                approvedValue
            );

            await catchRevert(
                dgLightToken.transferFrom(
                    owner,
                    expectedRecipient,
                    transferValue,
                    {
                        from: alice
                    }
                )
            );
        });
    });

    describe("Token Approval Functionality", () => {

        it("should assign value to allowance mapping", async () => {

            const approvalValue = ONE_TOKEN;

            await dgLightToken.approve(
                bob,
                approvalValue,
                {
                    from: owner
                }
            );

            const allowanceValue = await dgLightToken.allowance(
                owner,
                bob
            );

            assert.equal(
                approvalValue,
                allowanceValue
            );
        });

        it("should emit a correct Approval event", async () => {

            const transferValue = ONE_TOKEN;

            await dgLightToken.approve(
                bob,
                transferValue,
                {
                    from: owner
                }
            );

            const {
                _owner: transferOwner,
                _spender: spender,
                _value: value
            } = await getLastEvent(
                "Approval",
                dgLightToken
            );

            assert.equal(
                transferOwner,
                owner
            );

            assert.equal(
                spender,
                bob
            );

            assert.equal(
                value,
                transferValue
            );
        });
    });

    describe("GoLight Functionality", () => {

        it("should revert if there is no approval when using goLight", async () => {

            await catchRevert(
                dgLightToken.goLight(
                    ONE_TOKEN
                )
            );
        });

        it("should revert if the sender has spent more than their approved amount when using goLight", async () => {
        
            const approvedValue = ONE_TOKEN;
            const swapValue = THREE_ETH;

            await dgToken.approve(
                dgLightToken.address,
                approvedValue
            );
            await catchRevert(
                dgLightToken.goLight(
                    swapValue
                )
            );
        });

        it("should revert if not enough balance in the wallet", async () => {

            const balanceBefore = await dgToken.balanceOf(owner);

            await dgToken.approve(
                dgLightToken.address,
                balanceBefore.toString()
            );
            await catchRevert(
                dgLightToken.goLight(
                    balanceBefore.addn(1).toString()
                )
            );
        });

        it("should swap correct amount from DGToken to DGLightToken", async () => {

            for (let i = 0; i < testAmounts.length; i += 1) {
                const swapValue = web3.utils.toWei(testAmounts[i]);

                const dgBalanceBefore = await dgToken.balanceOf(owner);
                const balanceBefore = await dgLightToken.balanceOf(owner);

                await dgToken.approve(
                    dgLightToken.address,
                    swapValue
                );
                await dgLightToken.goLight(
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

        it("should revert if not enough balance in the wallet", async () => {

            const balanceBefore = await dgLightToken.balanceOf(owner);

            await catchRevert(
                dgLightToken.goClassic(
                    balanceBefore.div(RATIO).addn(1).toString()
                )
            );
        });

        it("should swap correct amount from DGLightToken to DGToken", async () => {

            for (let i = 0; i < testAmounts.length; i += 1) {
                const swapValue = web3.utils.toWei(testAmounts[i]);

                const dgBalanceBefore = await dgToken.balanceOf(owner);
                const balanceBefore = await dgLightToken.balanceOf(owner);

                await dgLightToken.goClassic(
                    swapValue
                );

                const dgBalanceAfter = await dgToken.balanceOf(owner);
                const balanceAfter = await dgLightToken.balanceOf(owner);

                assert.equal(
                    dgBalanceAfter.toString(),
                    dgBalanceBefore.add(BN(swapValue)).toString()
                );
                assert.equal(
                    balanceAfter.toString(),
                    balanceBefore.sub(BN(swapValue).mul(RATIO)).toString()
                );
            }
        });
    });
});
