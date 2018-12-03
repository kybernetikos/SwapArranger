pragma solidity ^0.5.0;

import "./ERC20.sol";

contract FlakyToken is ERC20 {
    string public name = "FlakyToken";
    string public symbol = "Flake";
    uint8 public decimals = 2;
    uint public INITIAL_SUPPLY = 12000;

    bool _shouldFlake = false;
    bool _shouldReject = false;

    constructor() public {
      _mint(msg.sender, INITIAL_SUPPLY);
    }

    function setFlake(bool flake) public {
        _shouldFlake = flake;
    }

    function setReject(bool reject) public {
        _shouldReject = reject;
    }

    /**
    * @dev Transfer token for a specified address
    * @param to The address to transfer to.
    * @param value The amount to be transferred.
    */
    function transfer(address to, uint256 value) public returns (bool) {
        require(!_shouldReject);

        if (!_shouldFlake) {
            _transfer(msg.sender, to, value);
            return true;
        }
        return false;
    }
}