pragma solidity ^0.4.18;

import "./RicoToken.sol";

contract ReentrancyGuard {

    /**
     * @dev We use a single lock for the whole contract.
     */
    bool private reentrancy_lock = false;

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * @notice If you mark a function `nonReentrant`, you should also
     * mark it `external`. Calling one nonReentrant function from
     * another is not supported. Instead, you can implement a
     * `private` function doing the actual work, and a `external`
     * wrapper marked as `nonReentrant`.
     */
    modifier nonReentrant() {
        require(!reentrancy_lock);
        reentrancy_lock = true;
        _;
        reentrancy_lock = false;
    }

}

contract DividendDistributor is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    RicoToken public token;

    // total wei on contract for all the time
    uint256 public totalWei;

    function DividendDistributor(address _token) public {
        require(_token != address(0));

        token = RicoToken(_token);
    }

    function getDividend() public nonReentrant returns (bool) {
        uint256 senderBalance = token.balanceOf(msg.sender);
        uint256 senderDividendPayments = token.dividendPayments(msg.sender);
        uint256 totalTokens = token.totalSupply();

        // calculate dividend amount
        uint256 dividend = totalWei.mul(senderBalance).div(totalTokens);

        // subtract dividend which has been taken by investor
        dividend = dividend.sub(senderDividendPayments);

        if (dividend > 0) {
            token.increaseDividendPayments(msg.sender, dividend);
            msg.sender.transfer(dividend);
            return true;
        }

        return false;
    }

    function() external payable {
        totalWei = totalWei.add(msg.value);
    }

}
