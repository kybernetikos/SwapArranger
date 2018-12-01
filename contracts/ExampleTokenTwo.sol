pragma solidity ^0.5.0;

import "./ERC20.sol";

contract ExampleTokenTwo is ERC20 {
    string public name = "ExampleToken2";
    string public symbol = "Ex2";
    uint8 public decimals = 2;
    uint public INITIAL_SUPPLY = 12000;

    constructor() public {
      _mint(msg.sender, INITIAL_SUPPLY);
    }
}