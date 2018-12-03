pragma solidity ^0.5.0;

import "./IERC20.sol";

contract Basket {
    address[] _erc20tokens;
    uint256[] _erc20amounts;
    uint256 _etherAmountWei;

    address _coordinator;
    address payable _commitBeneficiary;
    address payable _rollbackBeneficiary;

    address payable _finalBeneficiary;

    constructor(uint256 etherAmountWei, address[] memory erc20tokens, uint256[] memory erc20amounts, address payable rollbackBeneficiary, address payable  commitBeneficiary) public {
        require(erc20tokens.length > 0);
        require(erc20tokens.length == erc20amounts.length);
        require(rollbackBeneficiary != address(0));
        require(commitBeneficiary != address(0));

        _erc20tokens = erc20tokens;
        _erc20amounts = erc20amounts;
        _etherAmountWei = etherAmountWei;

        _coordinator = msg.sender;
        _rollbackBeneficiary = rollbackBeneficiary;
        _commitBeneficiary = commitBeneficiary;
    }

    function isReadyToCommit() public view returns(bool) {
        if (address(this).balance != _etherAmountWei) {
            return false;
        }

        uint len = _erc20tokens.length;
        for (uint i = 0; i < len; i++) {
            IERC20 tokenContract = IERC20(_erc20tokens[i]);
            uint256 requiredAmount = _erc20amounts[i];

            if (tokenContract.balanceOf(address(this)) != requiredAmount) {
                return false;
            }
        }
        return true;
    }

    function commit() public {
        if (_finalBeneficiary == address(0)) {
            // first time we're committing, only the coordinator can do it.
            require(msg.sender == _coordinator);
            require(isReadyToCommit());

            _finalBeneficiary = _commitBeneficiary;
        } else {
            // once it's locked in that we're committing, anyone can request it happens again....
            require(_finalBeneficiary == _commitBeneficiary);
        }

        closeOut();
    }

    function rollback() public {
        if (_finalBeneficiary == address(0)) {
            // first time we're rolling back, only the coordinator can do it.
            require(msg.sender == _coordinator);

            _finalBeneficiary = _rollbackBeneficiary;
        } else {
            // once it's locked in that we're rolling back, anyone can request it happens again....
            require(_finalBeneficiary == _rollbackBeneficiary);
        }

        closeOut();
    }

    // We want to make a best effort to transfer all assets from this basket out to the final beneficiary.
    // If any of the assets fail to transfer, we don't want that to stop the others from transferring.
    function closeOut() internal {
        uint len = _erc20tokens.length;
        for (uint i = 0; i < len; i++) {
            IERC20 tokenContract = IERC20(_erc20tokens[i]);

            // uint256 actualAmount = tokenContract.balanceOf(address(this));
            bytes memory payload1 = abi.encodeWithSignature("balanceOf(address)", address(this));
            (bool balanceCallSuccessful, bytes memory amountData) = address(tokenContract).call(payload1);

            if (balanceCallSuccessful) {
                (uint256 actualAmount) = abi.decode(amountData, (uint256));

                // tokenContract.transfer(_finalBeneficiary, actualAmount);
                bytes memory payload2 = abi.encodeWithSignature("transfer(address,uint256)", _finalBeneficiary, actualAmount);
                address(tokenContract).call(payload2);
            }
        }

        _finalBeneficiary.send(address(this).balance);
    }

    function () external payable {
        // don't want to receive more than we should.
        require(address(this).balance <= _etherAmountWei);
        // don't want to receive more after we've already closed out.
        require(_finalBeneficiary == address(0));
    }

    function getFinalBeneficiary() public view returns(address) {
        return _finalBeneficiary;
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

    function getEtherAmountRequired() public view returns(uint) {
        return _etherAmountWei;
    }

    function getCoordinator() public view returns(address) {
        return _coordinator;
    }

    function getRequiredTokensNumber() public view returns(uint) {
        return _erc20tokens.length;
    }

    function getRequiredToken(uint n) public view returns(address) {
        return _erc20tokens[n];
    }

    function getRequiredAmount(uint n) public view returns(uint) {
        return _erc20amounts[n];
    }
}