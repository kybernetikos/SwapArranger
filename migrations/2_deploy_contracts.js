const ExampleToken1 = artifacts.require("ExampleTokenOne");
const ExampleToken2 = artifacts.require("ExampleTokenTwo");
const SwapArranger = artifacts.require("SwapArranger");
const FlakyToken = artifacts.require("FlakyToken");

module.exports = function(deployer) {
    deployer.deploy(ExampleToken1);
    deployer.deploy(ExampleToken2);
    deployer.deploy(SwapArranger);
    deployer.deploy(FlakyToken);
};