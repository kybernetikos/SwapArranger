const TutorialToken = artifacts.require("TutorialToken");
const SwapArranger = artifacts.require("SwapArranger");

module.exports = function(deployer) {
    deployer.deploy(TutorialToken).then((ttAddress) => {
        return deployer.deploy(SwapArranger).then((swapper) => {
            console.log("Deployed SwapArranger", swapper.address);

            return swapper.arrange(
                '0x5d2aC199F8D906e263bd858D37924eb25E4a6018',
                [0, [ttAddress.address], [200]],
                '0x9b0e10193e3Dd98FF093a7566af28aD6Fa414f7C',
                [10, [ttAddress.address], [5]],
                100);
        });

    }).catch((e) => {
        console.error(e);
    });
};