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
const FOUR_ETH = web3.utils.toWei("3");
const FIVE_ETH = web3.utils.toWei("5");
const STATIC_SUPPLY = web3.utils.toWei("5000000");

const getLastEvent = async (eventName, instance) => {
    const events = await instance.getPastEvents(eventName, {
        fromBlock: 0,
        toBlock: "latest",
    });
    return events.pop().returnValues;
};

contract("Token", ([owner, alice, bob, random]) => {

    let dgLightToken;
    let dgToken;
    let launchTime;

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
                9e+33
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

            const { from, to, value } = await getLastEvent(
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
                ),
                "revert REQUIRES APPROVAL"
            );
        });

        it("should revert if the sender has spent more than their approved amount when using transferFrom", async () => {

            const approvedValue = ONE_TOKEN;
            const transferValue = FOUR_ETH;
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
                ),
                "revert AMOUNT EXCEEDS APPROVED VALUE"
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

            const { owner: transferOwner, spender, value } = await getLastEvent(
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

    describe("Master Functionality", () => {

        it("should have correct master address", async () => {

            const expectedAddress = owner;
            const masterAddress = await dgLightToken.master();

            assert.equal(
                expectedAddress,
                masterAddress
            );
        });

        it("should have correct master address based on from wallet", async () => {

            newToken = await Token.new(
                {from: alice}
            );

            const expectedAddress = alice;
            const masterAddress = await newToken.master();

            assert.equal(
                expectedAddress,
                masterAddress
            );
        });
    });

    describe("Mint Functionality", () => {

        it("should increase the balance of the wallet thats minting the tokens", async () => {

            const mintAmount = ONE_TOKEN;
            const supplyBefore = await dgLightToken.balanceOf(owner);

            await dgLightToken.mint(
                mintAmount,
                {
                    from: owner
                }

            );

            const supplyAfter = await dgLightToken.balanceOf(owner);

            assert.equal(
                parseInt(supplyAfter),
                parseInt(supplyBefore) + parseInt(mintAmount)
            );
        });

        it("should add the correct amount to the total supply", async () => {

            const supplyBefore = await dgLightToken.balanceOf(owner);
            const mintAmount = ONE_TOKEN;

            await dgLightToken.mint(
                mintAmount,
                {
                    from: owner
                }
            );

            const totalSupply = await dgLightToken.totalSupply();

            assert.equal(
                BN(totalSupply).toString(),
                (BN(supplyBefore).add(BN(mintAmount))).toString()
            );
        });

        it("should increase the balance for the wallet decided by master", async () => {

            const mintAmount = ONE_TOKEN;
            const mintWallet = bob;

            const supplyBefore = await dgLightToken.balanceOf(mintWallet);

            await dgLightToken.mintByMaster(
                mintAmount,
                mintWallet,
                {
                    from: owner
                }
            );

            const supplyAfter = await dgLightToken.balanceOf(mintWallet);

            assert.equal(
                parseInt(supplyAfter),
                parseInt(supplyBefore) + parseInt(mintAmount)
            );
        });

        it("should add the correct amount to the total supply (mintByMaster)", async () => {

            const mintWallet = bob;
            const mintAmount = ONE_TOKEN;

            const suppleBefore = await dgLightToken.totalSupply();

            await dgLightToken.mintByMaster(
                mintAmount,
                mintWallet,
                {
                    from: owner
                }
            );

            const supplyAfter = await dgLightToken.totalSupply();

            assert.equal(
                parseInt(supplyAfter),
                parseInt(suppleBefore) + parseInt(mintAmount)
            );
        });

        it("should only allow to mint from master address", async () => {

            const mintWallet = bob;
            const mintAmount = ONE_TOKEN;

            await catchRevert(
                dgLightToken.mintByMaster(
                    mintAmount,
                    mintWallet,
                    {
                        from: alice
                    }
                ),
                "revert Token: INVALID_MASTER"
            );
        });

    });
    describe("Burn Functionality", () => {

        it("should reduce the balance of the wallet thats burnng the tokens", async () => {

            const burnAmount = ONE_TOKEN;
            const supplyBefore = await dgLightToken.balanceOf(owner);

            await dgLightToken.burn(
                burnAmount,
                {
                    from: owner
                }

            );

            const supplyAfter = await dgLightToken.balanceOf(owner);

            assert.equal(
                supplyAfter,
                supplyBefore - burnAmount
            );
        });

        it("should deduct the correct amount from the total supply", async () => {

            const supplyBefore = await dgLightToken.balanceOf(owner);
            const burnAmount = ONE_TOKEN;

            await dgLightToken.burn(
                burnAmount,
                {
                    from: owner
                }

            );

            const totalSupply = await dgLightToken.totalSupply();

            assert.equal(
                totalSupply,
                supplyBefore - burnAmount
            );
        });
    });
});
