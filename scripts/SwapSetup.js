let swapper; SwapArranger.deployed().then(instance => swapper = instance), undefined;
let tToken; TutorialToken.deployed().then(instance => tToken = instance), undefined;

let rightLoad; swapper.getRightLoadAddress(0).then((addr) => rightLoad = addr), undefined;
let leftLoad; swapper.getLeftLoadAddress(0).then((addr) => leftLoad = addr), undefined;

tToken.transfer(leftLoad, 200);
tToken.transfer(rightLoad, 5);

let leftBasket; Basket.at(leftLoad).then((b) => leftBasket = b), undefined;
let rightBasket; Basket.at(rightLoad).then((b) => rightBasket = b), undefined;

rightBasket.send(10);

rightBasket.check();
