pragma solidity ^0.5.0;

import "./IERC20.sol";

contract Basket {
    address[] _tokens;
    uint256[] _amounts;
    uint256 _etherAmountWei;

    address _coordinator;
    address payable _commitBeneficiary;
    address payable _rollbackBeneficiary;

    constructor(uint256 etherAmountWei, address[] memory tokens, uint256[] memory amounts, address coordinator, address payable rollbackBeneficiary, address payable  commitBeneficiary) public {
        require(tokens.length > 0);
        require(tokens.length == amounts.length);

        _tokens = tokens;
        _amounts = amounts;
        _etherAmountWei = etherAmountWei;

        _coordinator = coordinator;
        _rollbackBeneficiary = rollbackBeneficiary;
        _commitBeneficiary = commitBeneficiary;
    }

    function getCoordinator() public view returns(address) {
        return _coordinator;
    }

    function check() public view returns(bool) {
        if (address(this).balance != _etherAmountWei) {
            return false;
        }

        uint len = _tokens.length;
        for (uint i = 0; i < len; i++) {
            IERC20 tokenContract = IERC20(_tokens[i]);
            uint256 requiredAmount = _amounts[i];

            if (tokenContract.balanceOf(address(this)) != requiredAmount) {
                return false;
            }
        }
        return true;
    }

    function commit() public {
        require(msg.sender == _coordinator);
        require(check());

        closeOut(_commitBeneficiary);
    }

    function rollback() public {
        require(msg.sender == _coordinator);

        closeOut(_rollbackBeneficiary);
    }

    function getRollbackBeneficiary() public view returns(address) {
        return _rollbackBeneficiary;
    }

    function getCommitBeneficiary() public view returns(address) {
        return _commitBeneficiary;
    }

    function getEtherAmount() public view returns(uint) {
        return address(this).balance;
    }
    function getEtherAmountExpected() public view returns(uint) {
        return _etherAmountWei;
    }

    function closeOut(address payable recipient) internal {
        uint len = _tokens.length;
        for (uint i = 0; i < len; i++) {
            IERC20 tokenContract = IERC20(_tokens[i]);
            uint256 actualAmount = tokenContract.balanceOf(address(this));
            tokenContract.transfer(recipient, actualAmount);
        }

        selfdestruct(recipient);
    }

    function () external payable {
        require(address(this).balance <= _etherAmountWei);
    }
}