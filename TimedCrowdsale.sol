pragma solidity ^0.4.23;

import "./SafeMath.sol";
import "./WhitelistedCrowdsale.sol";


/**
 * @title TimedCrowdsale
 * @dev Crowdsale accepting contributions only within a time frame.
 */
contract TimedCrowdsale is WhitelistedCrowdsale {
  using SafeMath for uint256;

  uint256 public openingTime;
  uint256 public closingTime;

  bool public paused;

  /**
   * @dev Reverts if not in crowdsale time range.
   */
  modifier onlyWhileOpen {
    // solium-disable-next-line security/no-block-members
    require(block.timestamp >= openingTime && block.timestamp <= closingTime && !paused);
    _;
  }

  modifier onlyWhenClosed {
    // solium-disable-next-line security/no-block-members
    require(block.timestamp >= openingTime && block.timestamp <= closingTime);
    _;
  }

  /**
   * @dev Constructor, takes crowdsale opening and closing times.
   * @param _openingTime Crowdsale opening time
   * @param _closingTime Crowdsale closing time
   */
  constructor(uint256 _openingTime, uint256 _closingTime, uint256 _rate, address _wallet, ERC20 _token, uint256 _totalForSale) public {
    // solium-disable-next-line security/no-block-members
    require(_openingTime >= block.timestamp);
    require(_closingTime >= _openingTime);

    openingTime = _openingTime;
    closingTime = _closingTime;

    paused = false;

    super(_rate, _wallet, _token, _totalForSale);
  }

  function pauseCrowdsale() public onlyOwner {
    paused = true;
  }

  function unPauseCrowdsale() public onlyOwner {
    paused = false;
  }

  function changeCrowdsaleClosingTime(uint256 _newClosingTime) public onlyOwner {
    closingTime = _newClosingTime;
  }
  

  function burnUnsoledTokens() public onlyWhenClosed {
    
    token.burn(totalForSale);
  }
  

  /**
   * @dev Checks whether the period in which the crowdsale is open has already elapsed.
   * @return Whether crowdsale period has elapsed
   */
  function hasClosed() public view returns (bool) {
    // solium-disable-next-line security/no-block-members
    return block.timestamp > closingTime;
  }

  /**
   * @dev Extend parent behavior requiring to be within contributing period
   * @param _beneficiary Token purchaser
   * @param _weiAmount Amount of wei contributed
   */
  function _preValidatePurchase(
    address _beneficiary,
    uint256 _weiAmount
  )
    internal
    onlyWhileOpen
  {
    super._preValidatePurchase(_beneficiary, _weiAmount);
  }

}