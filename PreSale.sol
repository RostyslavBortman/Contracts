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

contract PreSale is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    // The token being sold
    RicoToken public token;

    // start and end timestamps where investments are allowed (both inclusive)
    uint256 public startTime;
    uint256 public endTime;

    // Address where funds are transferred after success end of PreSale
    address public wallet;

    // How many token units a buyer gets per wei
    uint256 public rate;

    uint256 public minimumInvest; // in wei

    uint256 public softCap; // in wei
    uint256 public hardCap; // in wei

    // investors => amount of money
    mapping(address => uint) public balances;

    // Amount of wei raised
    uint256 public weiRaised;

    // PreSale bonus in percent
    uint256 bonusPercent;

    /**
     * event for token purchase logging
     * @param purchaser who paid for the tokens
     * @param beneficiary who got the tokens
     * @param value weis paid for purchase
     * @param amount amount of tokens purchased
     */
    event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);

    function PreSale(
        uint256 _startTime,
        uint256 _period,
        address _wallet,
        address _token,
        uint256 _minimumInvest) public
    {
        require(_period != 0);
        require(_token != address(0));

        startTime = _startTime;
        endTime = startTime + _period * 1 days;

        wallet = _wallet;
        token = RicoToken(_token);

        // minimumInvest in wei
        minimumInvest = _minimumInvest;

        // 1 token for approximately 0.00015 eth
        rate = 6667;

        softCap = 150 * 1 ether;
        hardCap = 1500 * 1 ether;
        bonusPercent = 50;
    }

    // @return true if the transaction can buy tokens
    modifier saleIsOn() {
        bool withinPeriod = now >= startTime && now <= endTime;
        require(withinPeriod);
        _;
    }

    modifier isUnderHardCap() {
        require(weiRaised < hardCap);
        _;
    }

    modifier refundAllowed() {
        require(weiRaised < softCap && now > endTime);
        _;
    }


    // @return true if PreSale event has ended
    function hasEnded() public view returns (bool) {
        return now > endTime;
    }

    // Refund ether to the investors
    function refund() public refundAllowed nonReentrant {
        uint256 valueToReturn = balances[msg.sender];

        // update states
        balances[msg.sender] = 0;
        weiRaised = weiRaised.sub(valueToReturn);

        // burn tokens
        uint256 tokens = getTokenAmount(valueToReturn);
        tokens = tokens.add(tokens.mul(bonusPercent).div(100));
        token.burnForRefund(msg.sender, tokens);

        msg.sender.transfer(valueToReturn);
    }

    // Get amount of tokens
    // @param value weis paid for tokens
    function getTokenAmount(uint256 _value) internal view returns (uint256) {
        return _value.mul(rate);
    }

    // Send weis to the wallet
    function forwardFunds(uint256 _value) internal {
        wallet.transfer(_value);
    }

    // Success finish of PreSale
    function finishPreSale() public onlyOwner {
        require(weiRaised >= softCap);
        require(weiRaised >= hardCap || now > endTime);

        if (now < endTime) {
            endTime = now;
        }

        forwardFunds(this.balance);
    }

    // low level token purchase function
    function buyTokens(address _beneficiary) saleIsOn isUnderHardCap nonReentrant public payable {
        require(_beneficiary != address(0));
        require(msg.value >= minimumInvest);

        uint256 weiAmount = msg.value;
        uint256 tokens = getTokenAmount(weiAmount);
        tokens = tokens.add(tokens.mul(bonusPercent).div(100));

        token.mint(_beneficiary, tokens);

        // update states
        weiRaised = weiRaised.add(weiAmount);
        balances[_beneficiary] = balances[_beneficiary].add(weiAmount);

        TokenPurchase(msg.sender, _beneficiary, weiAmount, tokens);
    }

    function() external payable {
        buyTokens(msg.sender);
    }
}