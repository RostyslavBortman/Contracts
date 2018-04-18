pragma solidity ^0.4.18;

import "./RicoToken.sol";
import "./PreSale.sol";


contract rICO is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    // The token being sold
    RicoToken public token;

    // PreSale
    PreSale public preSale;

    // Timestamps of periods
    uint256 public startTime;
    uint256 public endCrowdSaleTime;
    uint256 public endRefundableTime;


    // Address where funds are transferred
    address public wallet;

    // How many token units a buyer gets per wei
    uint256 public rate;

    uint256 public minimumInvest; // in wei

    uint256 public softCap; // in wei
    uint256 public hardCap; // in wei

    // investors => amount of money
    mapping(address => uint) public balances;
    mapping(address => uint) public balancesInToken;

    // Amount of wei raised
    uint256 public weiRaised;

    // Rest amount of wei after refunding by investors and withdraws by owner
    uint256 public restWei;

    // Amount of wei which reserved for withdraw by owner
    uint256 public reservedWei;

    // stages of Refundable part
    bool public firstStageRefund = false;  // allow 750 eth to withdraw
    bool public secondStageRefund = false;  // allow 30 percent of rest wei to withdraw
    bool public finalStageRefund = false;  // allow all rest wei to withdraw

    /**
     * event for token purchase logging
     * @param purchaser who paid for the tokens
     * @param beneficiary who got the tokens
     * @param value weis paid for purchase
     * @param amount amount of tokens purchased
     */
    event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);

    function rICO(
        uint256 _startTime,
        address _wallet,
        address _token,
        address _preSale,
        uint256 _minimumInvest) public
    {
        require(_token != address(0));

        startTime = _startTime;
        endCrowdSaleTime = startTime + 60 * 1 days;
        endRefundableTime = endCrowdSaleTime + 90 * 1 days;

        wallet = _wallet;
        token = RicoToken(_token);
        preSale = PreSale(_preSale);

        // minimumInvest in wei
        minimumInvest = _minimumInvest;

        // 1 token for approximately 0.00015 eth
        rate = 6667;

        softCap = 1500 * 1 ether;
        hardCap = 15000 * 1 ether;
    }

    // @return true if the transaction can buy tokens
    modifier saleIsOn() {
        bool withinPeriod = now >= startTime && now <= endCrowdSaleTime;
        require(withinPeriod);
        _;
    }

    modifier isUnderHardCap() {
        require(weiRaised.add(preSale.weiRaised()) < hardCap);
        _;
    }

    // unsuccessful end of CrowdSale
    modifier refundAllowed() {
        require(weiRaised.add(preSale.weiRaised()) < softCap && now > endCrowdSaleTime);
        _;
    }

    // successful end of CrowdSale
    modifier successRefundAllowed() {
        require(weiRaised.add(preSale.weiRaised()) >= softCap && now > endCrowdSaleTime && now <= endRefundableTime);
        _;
    }

    // @return true if CrowdSale event has ended
    function hasEnded() public view returns (bool) {
        return now > endRefundableTime;
    }

    // Get bonus percent
    function getBonusPercent() internal view returns(uint256) {
        uint256 collectedWei = weiRaised.add(preSale.weiRaised());

        if (collectedWei < 1500 * 1 ether) {
            return 20;
        }
        if (collectedWei < 5000 * 1 ether) {
            return 10;
        }
        if (collectedWei < 10000 * 1 ether) {
            return 5;
        }

        return 0;
    }

    // Get real value to return to investor
    function getRealValueToReturn(uint256 _value) internal view returns(uint256) {
        return _value.mul(restWei).div(weiRaised);
    }

    // Update of reservedWei for withdraw
    function updateReservedWei() public successRefundAllowed {
        uint256 curWei;

        if (!firstStageRefund && now > endCrowdSaleTime) {
            curWei = 750 * 1 ether;

            reservedWei = curWei;
            restWei = weiRaised.sub(curWei);

            firstStageRefund = true;
        }

        if (!secondStageRefund && now > endCrowdSaleTime + 60 * 1 days) {
            curWei = restWei.mul(30).div(100);

            reservedWei = reservedWei.add(curWei);
            restWei = restWei.sub(curWei);

            secondStageRefund = true;
        }

        if (!finalStageRefund && now > endRefundableTime) {
            reservedWei = reservedWei.add(restWei);
            restWei = 0;

            finalStageRefund = true;
        }

    }

    // Refund ether to the investors in case of unsuccessful end of CrowdSale
    function refund() public refundAllowed nonReentrant {
        uint256 valueToReturn = balances[msg.sender];
        uint256 tokensToReturn = balancesInToken[msg.sender];

        // update states
        balances[msg.sender] = 0;
        balancesInToken[msg.sender] = 0;
        weiRaised = weiRaised.sub(valueToReturn);

        // burn tokens
        token.burnForRefund(msg.sender, tokensToReturn);

        msg.sender.transfer(valueToReturn);
    }

    // Refund part of ether to the investors in case of successful end of CrowdSale
    function refundPart() public successRefundAllowed nonReentrant {
        uint256 valueToReturn = balances[msg.sender];
        uint256 tokensToReturn = balancesInToken[msg.sender];

        // get real value to return
        updateReservedWei();
        valueToReturn = getRealValueToReturn(valueToReturn);

        // update states
        balances[msg.sender] = 0;
        balancesInToken[msg.sender] = 0;
        restWei = restWei.sub(valueToReturn);

        // burn tokens
        token.burnForRefund(msg.sender, tokensToReturn);

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

    // Withdrawal eth to owner
    function withdrawal() public onlyOwner {
        require(weiRaised.add(preSale.weiRaised()) >= softCap && now > endCrowdSaleTime);

        updateReservedWei();

        uint256 withdrawalWei = reservedWei;
        reservedWei = 0;
        forwardFunds(withdrawalWei);
    }

    // Success finish of CrowdSale
    function finishCrowdSale() public onlyOwner {
        require(weiRaised.add(preSale.weiRaised()) >= softCap && now > endRefundableTime);

        // withdrawal all eth from contract
        updateReservedWei();
        reservedWei = 0;
        forwardFunds(this.balance);

        // mint tokens to owner - wallet
        token.mint(wallet, token.totalSupply().mul(42857).div(57143));
    }

    // low level token purchase function
    function buyTokens(address _beneficiary) saleIsOn isUnderHardCap nonReentrant public payable {
        require(_beneficiary != address(0));
        require(msg.value >= minimumInvest);

        uint256 weiAmount = msg.value;
        uint256 tokens = getTokenAmount(weiAmount);
        uint256 bonusPercent = getBonusPercent();
        tokens = tokens.add(tokens.mul(bonusPercent).div(100));

        token.mint(_beneficiary, tokens);

        // update states
        weiRaised = weiRaised.add(weiAmount);
        balances[_beneficiary] = balances[_beneficiary].add(weiAmount);
        balancesInToken[_beneficiary] = balancesInToken[_beneficiary].add(tokens);

        // update timestamps and begin Refundable stage
        if (weiRaised >= hardCap) {
            endCrowdSaleTime = now;
            endRefundableTime = endCrowdSaleTime + 90 * 1 days;
        }

        TokenPurchase(msg.sender, _beneficiary, weiAmount, tokens);
    }

    function() external payable {
        buyTokens(msg.sender);
    }
}