pragma solidity ^0.5.0;

import "./ERC20.sol";

contract ExampleTokenOne is ERC20 {
    string public name = "ExampleToken1";
    string public symbol = "Ex1";
    uint8 public decimals = 2;
    uint public INITIAL_SUPPLY = 12000;

    constructor() public {
      _mint(msg.sender, INITIAL_SUPPLY);
    }
}