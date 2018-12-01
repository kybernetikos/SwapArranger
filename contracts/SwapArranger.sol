pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "./Basket.sol";

contract SwapArranger {
    struct BasketContents {
        uint256 eth;
        address[] tokens;
        uint256[] amounts;
    }

    struct Swap {
        Basket left;
        Basket right;
        uint timeout;
    }

    uint _nextId;
    mapping (uint=>Swap) _currentSwaps;

    constructor() public {
        _nextId = 0;
    }

    function arrange(
            address payable left, BasketContents memory leftContents,
            address payable right, BasketContents memory rightContents,
            uint liveTimeSeconds) public returns(uint) {

        uint id = _nextId;
        _nextId += 1;
        uint timeout = now + liveTimeSeconds;

        Basket leftBasket = makeBasket(leftContents, left, right);
        Basket rightBasket = makeBasket(rightContents, right, left);

        _currentSwaps[id] = Swap(
            leftBasket, rightBasket,
            timeout
        );

        return id;
    }

    function makeBasket(BasketContents memory contents, address payable source, address payable destination) internal returns(Basket) {
        return new Basket(contents.eth, contents.tokens, contents.amounts, source, destination);
    }

    function commit(uint id) public {
        require(isReadyToCommit(id));

        _currentSwaps[id].left.commit();
        _currentSwaps[id].right.commit();

        delete _currentSwaps[id];
    }

    function rollback(uint id) public {
        require(getTimeRemainingSeconds(id) == 0);

        _currentSwaps[id].left.rollback();
        _currentSwaps[id].right.rollback();

        delete _currentSwaps[id];
    }

    function getTimeRemainingSeconds(uint id) public view returns(uint) {
        if (_currentSwaps[id].timeout <= now) {
            return 0;
        }
        return _currentSwaps[id].timeout - now;
    }

    function getLeftLoadAddress(uint id) public view returns(address) {
        return address(_currentSwaps[id].left);
    }

    function getRightLoadAddress(uint id) public view returns(address) {
        return address(_currentSwaps[id].right);
    }

    function getLeftParticipant(uint id) public view returns(address) {
        return _currentSwaps[id].left.getRollbackBeneficiary();
    }

    function getRightParticipant(uint id) public view returns(address) {
        return _currentSwaps[id].right.getRollbackBeneficiary();
    }

    function isLeftComplete(uint id) public view returns(bool) {
        return _currentSwaps[id].left.isReadyToCommit();
    }

    function isRightComplete(uint id) public view returns(bool) {
        return _currentSwaps[id].right.isReadyToCommit();
    }

    function isReadyToCommit(uint id) public view returns(bool) {
        return isLeftComplete(id) && isRightComplete(id);
    }
}