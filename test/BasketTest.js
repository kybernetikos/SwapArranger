const ExampleToken1 = artifacts.require("ExampleTokenOne");
const ExampleToken2 = artifacts.require("ExampleTokenTwo");
const Basket = artifacts.require("Basket");
const BN = web3.utils.BN;

const nobody  = '0x0000000000000000000000000000000000000000';

contract('Basket', async([alice, bob, carol, dave, eve, frank, grace, harry, irene, joe]) => {
    it("when newly initialised with requirements, but no contents is not ready to commit.", async () => {
        const basket = await Basket.new(30, [ExampleToken1.address, ExampleToken2.address], [100, 20], bob, carol);
        assert.isFalse(await basket.isReadyToCommit());

        try {
            await basket.commit();
            fail("Commit should fail.");
        } catch (e) {
            assert.include(e.message, "revert");
        }
    });

    it("when filled, can commit and the commit beneficiary receives the tokens.", async () => {
        const [token1, token2] = await Promise.all([ExampleToken1.deployed(), ExampleToken2.deployed()]);
        const basket = await Basket.new(30, [ExampleToken1.address, ExampleToken2.address], [100, 20], bob, carol);
        const balances = () => Promise.all([
            token1.balanceOf(basket.address),
            token1.balanceOf(bob),
            token1.balanceOf(carol),
            token2.balanceOf(basket.address),
            token2.balanceOf(bob),
            token2.balanceOf(carol)
        ]).then((arr) => arr.map((n) => n.toNumber()));

        assert.sameOrderedMembers(await balances(), [0, 0, 0, 0, 0, 0]);
        const carolEth = new BN(await web3.eth.getBalance(carol));

        await Promise.all([
            token1.transfer(basket.address, 100),
            token2.transfer(basket.address, 20),
            basket.send(30)
        ]);

        assert.isTrue(await basket.isReadyToCommit());

        await basket.commit();

        assert.sameOrderedMembers(await balances(), [0, 0, 100, 0, 0, 20]);
        assert.equal(await web3.eth.getBalance(carol), carolEth.addn(30).toString());
    });
});