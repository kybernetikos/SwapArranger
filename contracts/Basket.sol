pragma solidity ^0.5.0;

import "./IERC20.sol";

/**
 * @dev Implementation of a basket that can hold various assets, and that can transfer ownership between two identified
 * parties.
 */
contract Basket {
    // I don't believe I need safemath because the only maths I need are comparisons.

    event Erc20TransferFailed(
        address indexed token,
        address indexed basket,
        address indexed to,
        uint256 value
    );

    event EthTransferFailed(
        address indexed basket,
        address indexed to,
        uint256 value
    );

    event BasketCommitted(
        address indexed basket,
        address indexed to,
        bool clean
    );

    event BasketRolledBack(
        address indexed basket,
        address indexed to,
        bool clean
    );

    // An array of erc20 token addresses.  Matches up with the amounts array.
    address[] _untrustedErc20tokens;

    // An array of the amounts required of each erc20 token.  Must be the same length as _erc20tokens.
    uint256[] _erc20amounts;

    // The amount of ether required to fill the basket (along with other assets).  May be 0.
    uint256 _etherAmountWei;

    /**
     * @dev The coordinator is whatever address constructed this Basket contract.
     * The coordinator decides whether this basket should be committed or rolled back.
     */
    address _coordinator;

    // The _commitBeneficiary is the address of whomever will receive the contents of this basket if it commits.
    address payable _commitBeneficiary;

    // The _rollbackBeneficiary is the address of whomever will receive the contents of this basket if it rolls back.
    address payable _rollbackBeneficiary;

    /**
     * @dev Before the coordinator decides whether to commit or roll back, the _finalBeneficiary is address(0).  Once
     * committing or rolling back is locked in, the _finalBeneficiary changes to one of _commitBeneficiary or
     * _rollbackBeneficiary, and should not change again.
     */
    address payable _finalBeneficiary;

    constructor(uint256 etherAmountWei, address[] memory erc20tokens, uint256[] memory erc20amounts, address payable rollbackBeneficiary, address payable  commitBeneficiary) public {
        require(erc20tokens.length > 0);
        require(erc20tokens.length == erc20amounts.length);
        require(rollbackBeneficiary != address(0));
        require(commitBeneficiary != address(0));

        _untrustedErc20tokens = erc20tokens;
        _erc20amounts = erc20amounts;
        _etherAmountWei = etherAmountWei;

        _coordinator = msg.sender;
        _rollbackBeneficiary = rollbackBeneficiary;
        _commitBeneficiary = commitBeneficiary;
    }

    /**
     * @dev returns true if the basket's is known to have assets matching its requirements, false otherwise.
     * This implies that all the ERC20 tokens responded appropriately to a balanceOf request.
     */
    function isReadyToCommit() public view returns(bool) {
        if (address(this).balance != _etherAmountWei) {
            return false;
        }

        uint len = _untrustedErc20tokens.length;
        for (uint i = 0; i < len; i++) {
            IERC20 untrustedTokenContract = IERC20(_untrustedErc20tokens[i]);
            uint256 requiredAmount = _erc20amounts[i];

            if (untrustedTokenContract.balanceOf(address(this)) != requiredAmount) {
                return false;
            }
        }
        return true;
    }

    /**
     * @dev Lock the basket to pay out to the commitBeneficiary, close out the basket.
     * The first time we commit, only the coordinator is allowed to do it, although if the basket has acquired more
     * assets, or something went wrong during the initial commit, then it can be called subsequently by anyone to
     * transfer those assets to the commitBeneficiary.
     * We can only commit initially if this basket is 'full' i.e. it has assets matching all of its requirements.
     * If all transfers were completed successfully, returns true, otherwise false.
     */
    function commit() public returns(bool) {
        if (_finalBeneficiary == address(0)) {
            // first time we're committing, only the coordinator can do it.
            require(msg.sender == _coordinator);
            require(isReadyToCommit());

            _finalBeneficiary = _commitBeneficiary;
        } else {
            // once it's locked in that we're committing, anyone can request it happens again....
            require(_finalBeneficiary == _commitBeneficiary);
        }

        bool clean = closeOut();

        emit BasketCommitted(address(this), _finalBeneficiary, clean);

        return clean;
    }

    /**
     * @dev Lock the basket to pay out to the rollbackBeneficiary, close out the basket.
     * The first time we commit, only the coordinator is allowed to do it, although if the basket has acquired more
     * assets, or something went wrong during the initial rollback, then it can be called subsequently by anyone to
     * transfer those assets to the rollbackBeneficiary.
     * There is no requirement that the basket be full to rollback.
     * If all transfers were completed successfully, returns true, otherwise false.
     */
    function rollback() public returns(bool) {
        if (_finalBeneficiary == address(0)) {
            // first time we're rolling back, only the coordinator can do it.
            require(msg.sender == _coordinator);

            _finalBeneficiary = _rollbackBeneficiary;
        } else {
            // once it's locked in that we're rolling back, anyone can request it happens again....
            require(_finalBeneficiary == _rollbackBeneficiary);
        }

        bool clean = closeOut();

        emit BasketRolledBack(address(this), _finalBeneficiary, clean);

        return clean;
    }

    /**
     * @dev closeOut is called during commit or rollback.
     * It makes a best effort to transfer all assets from this basket out to the final beneficiary.
     * Any transfers that cause problems should not stop other assets from being transferred.
     */
    function closeOut() internal returns (bool) {
        uint len = _untrustedErc20tokens.length;
        bool allErc20TransfersSuccessful = true;
        for (uint i = 0; i < len; i++) {
            IERC20 untrustedToken = IERC20(_untrustedErc20tokens[i]);

            bool thisTransferSucceeded = false;
            uint256 actualAmount = 0;

            // uint256 actualAmount = tokenContract.balanceOf(address(this));
            bytes memory payload1 = abi.encodeWithSignature("balanceOf(address)", address(this));
            (bool balanceCallSuccessful, bytes memory amountData) = address(untrustedToken).call(payload1);

            if (balanceCallSuccessful) {
                (actualAmount) = abi.decode(amountData, (uint256));

                // tokenContract.transfer(_finalBeneficiary, actualAmount);
                bytes memory payload2 = abi.encodeWithSignature("transfer(address,uint256)", _finalBeneficiary, actualAmount);
                (bool transferCallSuccessful, bytes memory transferResponseData) = address(untrustedToken).call(payload2);
                if (transferCallSuccessful) {
                    thisTransferSucceeded = abi.decode(transferResponseData, (bool));
                }
            }

            if (!thisTransferSucceeded) {
                emit Erc20TransferFailed(address(untrustedToken), address(this), _finalBeneficiary, actualAmount);
            }

            allErc20TransfersSuccessful = allErc20TransfersSuccessful && thisTransferSucceeded;
        }

        uint256 ethBalance = address(this).balance;
        bool ethTransferSucceeded = _finalBeneficiary.send(ethBalance);
        if (!ethTransferSucceeded) {
            emit EthTransferFailed(address(this), _finalBeneficiary, ethBalance);
        }
        return ethTransferSucceeded && allErc20TransfersSuccessful;
    }

    // Receive ether.
    function () external payable {
        // don't want to receive more than we should.
        require(address(this).balance <= _etherAmountWei);
        // don't want to receive more after we've already closed out.
        require(_finalBeneficiary == address(0));
    }

    // returns the locked in beneficiary of this basket, or address(0) if no beneficiary has been chosen yet.
    function getFinalBeneficiary() public view returns(address) {
        return _finalBeneficiary;
    }

    // returns the beneficiary if the basket rolls back.  It's expected that this will be the party responsible for loading the basket.
    function getRollbackBeneficiary() public view returns(address) {
        return _rollbackBeneficiary;
    }

    // returns the beneficiary if the basket commits.
    function getCommitBeneficiary() public view returns(address) {
        return _commitBeneficiary;
    }

    // returns the amount of ether required in this basket.
    function getEtherAmountRequired() public view returns(uint) {
        return _etherAmountWei;
    }

    // the address of the party responsible for choosing whether this basket commits or rolls back.
    function getCoordinator() public view returns(address) {
        return _coordinator;
    }

    // returns the number of ERC20 token types that this basket requires.
    function getRequiredTokensNumber() public view returns(uint) {
        return _untrustedErc20tokens.length;
    }

    // returns the address of one of the ERC20 token types that this basket requires.
    function getRequiredToken(uint n) public view returns(address) {
        return _untrustedErc20tokens[n];
    }

    // returns the amount of an ERC20 token types that this basket requires.
    function getRequiredAmount(uint n) public view returns(uint) {
        return _erc20amounts[n];
    }

    // Allows tokens transferred to this basket to be transferred out to the beneficiary. This is intended as a last
    // ditch effort to recover tokens if something has gone wrong.
    function rescueErc20(address token) public returns(bool) {
        require (_finalBeneficiary != address(0));

        // it's not clear to me if the beneficiary is the right person to transfer these tokens to, since they were
        // probably not intended to be part of the basket.  Other choices are the rollbackBeneficiary, which would make
        // sense for tokens transferred in error, or the coordinator as a kind of 'supervisor'.
        // At the moment, I've gone with the locked in final beneficiary, as anything else would seem more complicated
        // to be confident the contract was behaving correctly (e.g. what if a token didn't transfer correctly during
        // the initial commit but would now? - that one *should* go to the _commitBeneficiary).
        return IERC20(token).transfer(_finalBeneficiary, IERC20(token).balanceOf(address(this)));
    }
}