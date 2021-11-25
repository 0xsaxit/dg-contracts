const DGToken = artifacts.require("dgToken");
const DGTownHall = artifacts.require("DGTownHall");
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

const getxDGAmount = (dgAmount, dgTotal, xDGTotal) => {
    if (dgTotal.isZero() || xDGTotal.isZero()) {
        return dgAmount;
    }
    return dgAmount.mul(xDGTotal).div(dgTotal);
}

const getDGAmount = (xDGAmount, dgTotal, xDGTotal) => {
    return BN(xDGAmount).mul(dgTotal).div(xDGTotal);
}

contract("DGTownHall", ([owner, alice, bob, random]) => {

    let dgTownHall;
    let dgToken;

    beforeEach(async () => {
        dgToken = await DGToken.new();
        dgTownHall = await DGTownHall.new(dgToken.address);
        await dgToken.approve(dgTownHall.address, STATIC_SUPPLY);
        await dgTownHall.stepInside(STATIC_SUPPLY);
    });

    describe("Token Initial Values", () => {

        it("should have correct token name", async () => {
            const name = await dgTownHall.name();
            assert.equal(
                name,
                "Decentral Games Governance"
            );
        });

        it("should have correct token symbol", async () => {
            const symbol = await dgTownHall.symbol();
            assert.equal(
                symbol,
                "xDG"
            );
        });

        it("should have correct token decimals", async () => {
            const decimals = await dgTownHall.decimals();
            assert.equal(
                decimals,
                18
            );
        });

        it("should have correct token supply", async () => {
            const supply = await dgTownHall.totalSupply();
            assert.equal(
                supply,
                STATIC_SUPPLY
            );
        });

        it("should have correct inner supply", async () => {
            const innerSupply = await dgTownHall.innerSupply();
            assert.equal(
                innerSupply,
                STATIC_SUPPLY
            );
        });

        it("should have correct inside amount", async () => {
            const insideAmount = await dgTownHall.insideAmount(STATIC_SUPPLY);
            assert.equal(
                insideAmount,
                STATIC_SUPPLY
            );
        });

        it("should have correct outside amount", async () => {
            const outsideAmount = await dgTownHall.outsidAmount(STATIC_SUPPLY);
            assert.equal(
                outsideAmount,
                STATIC_SUPPLY
            );
        });

        it("should have correct DG amount", async () => {
            const dgAmount = await dgTownHall.DGAmount(owner);
            assert.equal(
                dgAmount,
                STATIC_SUPPLY
            );
        });

        it("should return the correct balance for the given account", async () => {
            const expectedAmount = ONE_TOKEN;

            await dgTownHall.transfer(
                bob,
                expectedAmount,
                {
                    from: owner
                }
            );

            const balance = await dgTownHall.balanceOf(bob);

            assert.equal(
                balance,
                expectedAmount
            );
        });

        it("should return the correct allowance for the given spender", async () => {
            const allowance = await dgTownHall.allowance(owner, bob);
            assert.equal(
                allowance,
                0
            );
        });
    });

    describe("Token Transfer Functionality", () => {

        it("should transfer correct amount from walletA to walletB", async () => {

            const transferValue = ONE_TOKEN;
            const balanceBefore = await dgTownHall.balanceOf(bob);

            await dgTownHall.transfer(
                bob,
                transferValue,
                {
                    from: owner
                }
            );

            const balanceAfter = await dgTownHall.balanceOf(bob);

            assert.equal(
                parseInt(balanceAfter),
                parseInt(balanceBefore) + parseInt(transferValue)
            );
        });

        it("should revert if not enough balance in the wallet", async () => {

            const balanceBefore = await dgTownHall.balanceOf(alice);

            await catchRevert(
                dgTownHall.transfer(
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
            const balanceBefore = await dgTownHall.balanceOf(owner);

            await dgTownHall.transfer(
                bob,
                transferValue,
                {
                    from: owner
                }
            );

            const balanceAfter = await dgTownHall.balanceOf(owner);

            assert.equal(
                parseInt(balanceAfter),
                parseInt(balanceBefore) - parseInt(transferValue)
            );
        });

        it("should emit correct Transfer event", async () => {

            const transferValue = ONE_TOKEN;
            const expectedRecepient = bob;

            await dgTownHall.transfer(
                expectedRecepient,
                transferValue,
                {
                    from: owner
                }
            );

            const { _from: from, _to: to, _value: value } = await getLastEvent(
                "Transfer",
                dgTownHall
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
            const balanceBefore = await dgTownHall.balanceOf(bob);

            await dgTownHall.approve(
                owner,
                transferValue
            );

            await dgTownHall.transferFrom(
                owner,
                expectedRecipient,
                transferValue,
            );

            const balanceAfter = await dgTownHall.balanceOf(bob);

            assert.equal(
                parseInt(balanceAfter),
                parseInt(balanceBefore) + parseInt(transferValue)
            );
        });

        it("should deduct from the balance of the sender when using transferFrom", async () => {
            const transferValue = ONE_TOKEN;
            const expectedRecipient = bob;
            const balanceBefore = await dgTownHall.balanceOf(owner);

            await dgTownHall.approve(
                owner,
                transferValue
            );

            await dgTownHall.transferFrom(
                owner,
                expectedRecipient,
                transferValue,
            );

            const balanceAfter = await dgTownHall.balanceOf(owner);

            assert.equal(
                parseInt(balanceAfter),
                parseInt(balanceBefore) - parseInt(transferValue)
            );
        });

        it("should revert if there is no approval when using transferFrom", async () => {
            const transferValue = ONE_TOKEN;
            const expectedRecipient = bob;

            await catchRevert(
                dgTownHall.transferFrom(
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

            await dgTownHall.approve(
                alice,
                approvedValue
            );

            await catchRevert(
                dgTownHall.transferFrom(
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

            await dgTownHall.approve(
                bob,
                approvalValue,
                {
                    from: owner
                }
            );

            const allowanceValue = await dgTownHall.allowance(
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

            await dgTownHall.approve(
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
                dgTownHall
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

    describe("StepInside Functionality", () => {

        it("should revert if there is no approval when using stepInside", async () => {

            await catchRevert(
                dgTownHall.stepInside(
                    ONE_TOKEN
                )
            );
        });

        it("should revert if the sender has spent more than their approved amount when using stepInside", async () => {
        
            const approvedValue = ONE_TOKEN;
            const swapValue = THREE_ETH;

            await dgToken.approve(
                dgTownHall.address,
                approvedValue
            );
            await catchRevert(
                dgTownHall.stepInside(
                    swapValue
                )
            );
        });

        it("should revert if not enough balance in the wallet", async () => {

            const balanceBefore = await dgToken.balanceOf(owner);

            await dgToken.approve(
                dgTownHall.address,
                balanceBefore.toString()
            );
            await catchRevert(
                dgTownHall.stepInside(
                    balanceBefore.addn(1).toString()
                )
            );
        });

        it("should stake correct amount of DG Token", async () => {

            for (let i = 0; i < testAmounts.length; i += 1) {
                const stakeValue = web3.utils.toWei(testAmounts[i]);

                const dgBalanceBefore = await dgToken.balanceOf(owner);
                const xDGBalanceBefore = await dgTownHall.balanceOf(owner);
                const dgTotalBefore = await dgTownHall.innerSupply();
                const xDGTotalBefore = await dgTownHall.totalSupply();

                const xDGAmount = getxDGAmount(
                    BN(stakeValue),
                    dgTotalBefore,
                    xDGTotalBefore
                );

                await dgToken.approve(
                    dgTownHall.address,
                    stakeValue
                );
                await dgTownHall.stepInside(
                    stakeValue
                );

                const dgBalanceAfter = await dgToken.balanceOf(owner);
                const xDGBalanceAfter = await dgTownHall.balanceOf(owner);
                const dgTotalAfter = await dgTownHall.innerSupply();
                const xDGTotalAfter = await dgTownHall.totalSupply();

                assert.equal(
                    dgTotalAfter.toString(),
                    dgTotalBefore.add(BN(stakeValue)).toString()
                )
                assert.equal(
                    xDGTotalAfter.toString(),
                    xDGTotalBefore.add(xDGAmount).toString()
                )
                assert.equal(
                    dgBalanceAfter.toString(),
                    dgBalanceBefore.sub(BN(stakeValue)).toString()
                );
                assert.equal(
                    xDGBalanceAfter.toString(),
                    xDGBalanceBefore.add(xDGAmount).toString()
                );
            }
        });
    });

    describe("StepOutside Functionality", () => {

        it("should revert if not enough balance in the wallet", async () => {

            const balanceBefore = await dgTownHall.balanceOf(owner);

            await catchRevert(
                dgTownHall.stepOutside(
                    balanceBefore.addn(1).toString()
                )
            );
        });

        it("should unstake correct amount of xDG Token", async () => {
            for (let i = 0; i < testAmounts.length; i += 1) {
                const stakeValue = web3.utils.toWei(testAmounts[i]);

                const dgBalanceBefore = await dgToken.balanceOf(owner);
                const xDGBalanceBefore = await dgTownHall.balanceOf(owner);
                const dgTotalBefore = await dgTownHall.innerSupply();
                const xDGTotalBefore = await dgTownHall.totalSupply();

                const dgAmount = getDGAmount(
                    BN(stakeValue),
                    dgTotalBefore,
                    xDGTotalBefore
                );

                await dgTownHall.stepOutside(
                    stakeValue
                );

                const dgBalanceAfter = await dgToken.balanceOf(owner);
                const xDGBalanceAfter = await dgTownHall.balanceOf(owner);
                const dgTotalAfter = await dgTownHall.innerSupply();
                const xDGTotalAfter = await dgTownHall.totalSupply();

                assert.equal(
                    dgTotalAfter.toString(),
                    dgTotalBefore.sub(dgAmount).toString()
                )
                assert.equal(
                    xDGTotalAfter.toString(),
                    xDGTotalBefore.sub(BN(stakeValue)).toString()
                )
                assert.equal(
                    dgBalanceAfter.toString(),
                    dgBalanceBefore.add(dgAmount).toString()
                );
                assert.equal(
                    xDGBalanceAfter.toString(),
                    xDGBalanceBefore.sub(BN(stakeValue)).toString()
                );
            }
        });
    });
});
