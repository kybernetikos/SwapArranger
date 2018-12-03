const ExampleToken1 = artifacts.require("ExampleTokenOne");
const ExampleToken2 = artifacts.require("ExampleTokenTwo");
const ExampleFlakyToken = artifacts.require("FlakyToken");
const Basket = artifacts.require("Basket");

const BN = web3.utils.BN;
const nobody  = '0x0000000000000000000000000000000000000000';

contract('Basket', async([alice, bob, carol, dave, eve, frank, grace, harry, irene, joe]) => {
    let token1, token2, balances, flakyToken;

    beforeEach(async () => {
        [token1, token2, flakyToken] = await Promise.all([ExampleToken1.new(), ExampleToken2.new(), ExampleFlakyToken.new()]);
        balances = (basket) => Promise.all([
            token1.balanceOf(basket.address),
            token1.balanceOf(bob),
            token1.balanceOf(carol),
            token2.balanceOf(basket.address),
            token2.balanceOf(bob),
            token2.balanceOf(carol),
            flakyToken.balanceOf(basket.address),
            flakyToken.balanceOf(bob),
            flakyToken.balanceOf(carol)
        ]).then((arr) => arr.map((n) => n.toNumber()));
    });

    it("when newly initialised with requirements, but is not filled, it cannot commit.", async () => {
        const basket = await Basket.new(30, [token1.address, token2.address], [100, 20], bob, carol);

        assert.isFalse(await basket.isReadyToCommit());
        try {
            await basket.commit();
            fail("Commit should fail.");
        } catch (e) {
            assert.include(e.message, "revert");
        }

        // ... nearly fill the basket...
        await Promise.all([
            token1.transfer(basket.address, 100),
            token2.transfer(basket.address, 19),
            basket.send(30)
        ]);

        // it should still not be commitable.
        assert.isFalse(await basket.isReadyToCommit());
        try {
            await basket.commit();
            fail("Commit should fail.");
        } catch (e) {
            assert.include(e.message, "revert");
        }
    });

    it("when filled, can commit and the commit beneficiary receives the tokens.", async () => {
        const basket = await Basket.new(30, [token1.address, token2.address], [100, 20], bob, carol);

        assert.sameOrderedMembers(await balances(basket), [0, 0, 0, 0, 0, 0, 0, 0, 0]);
        const carolEth = new BN(await web3.eth.getBalance(carol));

        await Promise.all([
            token1.transfer(basket.address, 100),
            token2.transfer(basket.address, 20),
            basket.send(30)
        ]);

        assert.isTrue(await basket.isReadyToCommit());

        await basket.commit();

        assert.sameOrderedMembers(await balances(basket), [0, 0, 100, 0, 0, 20, 0, 0, 0]);
        assert.equal(await web3.eth.getBalance(carol), carolEth.addn(30).toString());
    });

    it("if not filled, can rollback and the rollback beneficiary receives the tokens.", async () => {
        const basket = await Basket.new(30, [token1.address, token2.address], [100, 20], bob, carol);
        const bobEth = new BN(await web3.eth.getBalance(bob));

        assert.sameOrderedMembers(await balances(basket), [0, 0, 0, 0, 0, 0, 0, 0, 0]);

        // ... nearly fill the basket...
        await Promise.all([
            token1.transfer(basket.address, 100),
            token2.transfer(basket.address, 19),
            basket.send(30)
        ]);

        // it should still not be commitable.
        assert.isFalse(await basket.isReadyToCommit());

        // but we can roll back.
        await basket.rollback();

        assert.sameOrderedMembers(await balances(basket), [0, 100, 0, 0, 19, 0, 0, 0, 0]);
        assert.equal(await web3.eth.getBalance(bob), bobEth.addn(30).toString());
    });

    it("when rolling back will not be stopped by a flaky token.", async () => {
        const basket = await Basket.new(0, [token1.address, flakyToken.address, token2.address], [100, 20, 30], bob, carol);

        await Promise.all([
            token1.transfer(basket.address, 100),
            flakyToken.transfer(basket.address, 20),
            token2.transfer(basket.address, 30)
        ]);

        await flakyToken.setFlake(true);
        await basket.rollback();

        assert.sameOrderedMembers(await balances(basket), [0, 100, 0, 0, 30, 0, 20, 0, 0]);
    });

    it("when rolling back will not be stopped by a rejecting token.", async () => {
        const basket = await Basket.new(0, [token1.address, flakyToken.address, token2.address], [100, 20, 30], bob, carol);

        await Promise.all([
            token1.transfer(basket.address, 100),
            flakyToken.transfer(basket.address, 20),
            token2.transfer(basket.address, 30)
        ]);

        await flakyToken.setReject(true);
        await basket.rollback();

        assert.sameOrderedMembers(await balances(basket), [0, 100, 0, 0, 30, 0, 20, 0, 0]);

        // If the flaky coin fixes later...
        await flakyToken.setReject(false);

        // We can no longer commit - we've already locked in that this basket is being rolled back.
        try {
            await basket.commit();
            fail("Commit should fail.");
        } catch (e) {
            assert.include(e.message, "revert");
        }

        // but we can rollback again to retrieve the remaining flaky tokens.
        await basket.rollback();

        assert.sameOrderedMembers(await balances(basket), [0, 100, 0, 0, 30, 0, 0, 20, 0]);

    });
});