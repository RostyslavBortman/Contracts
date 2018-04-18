var increaseTimeTo = require('./helpers/increaseTime');
var latestTime = require('./helpers/latestTime');
var advanceBlock = require('./helpers/advanceToBlock');

const BigNumber = web3.BigNumber;
const duration = {
  seconds: function (val) { return val; },
  minutes: function (val) { return val * this.seconds(60); },
  hours: function (val) { return val * this.minutes(60); },
  days: function (val) { return val * this.hours(24); },
  weeks: function (val) { return val * this.days(7); },
  years: function (val) { return val * this.days(365); },
};

require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bignumber')(BigNumber))
  .should();

var chai = require('chai');
var assert = chai.assert;

const DelayedPayment = artifacts.require('DelayedPayment');


contract('DelayedPayment', function () {

    before(async function () {
    // Advance to the next block to correctly read time in the solidity "now" function interpreted by ganache
    await advanceBlock();
    });

    beforeEach(async function () {

    this.contract =  await DelayedPayment.new();

  });

    describe('Deposit and withdraw', function () {
     it('should pass', async function () {
      var gasUsed;
      var balanceAfterDeposit;
      var gasCostAdditional; // when we do transfer in the contract in withdraw method
      var gasPrice = web3.eth.gasPrice.toNumber();
      var oldBalance = web3.eth.getBalance(web3.eth.accounts[1]).toNumber();

      await this.contract.deposit(1,{from: web3.eth.accounts[1], value: web3.toWei(1, "ether")}).then(function(tx) {
         gasUsed = tx.receipt.gasUsed;
      });

      balanceAfterDeposit = web3.eth.getBalance(web3.eth.accounts[1]).toNumber();
      var gasCost = gasUsed * gasPrice;
      assert.notEqual(oldBalance - gasCost, balanceAfterDeposit);
      await increaseTimeTo(duration.hours(2));
      await this.contract.withdraw({from: web3.eth.accounts[1]}).then(function(tx) {
         gasUsed = gasUsed + tx.receipt.gasUsed;
      });

      gasCost = gasUsed * gasPrice;
      gasCostAdditional = oldBalance - web3.eth.getBalance(web3.eth.accounts[1]).toNumber() - gasCost;

      assert.equal(web3.fromWei(gasCostAdditional) < 0.1, true);
      var balanceAfterWithdraw = web3.eth.getBalance(web3.eth.accounts[1]).toNumber();
      gasCost = gasCost + gasCostAdditional;


      assert.equal(oldBalance - gasCost, balanceAfterWithdraw);
      
     });

     it('should fail due to no end locked eth', async function () {
      await this.contract.deposit(5,{from: web3.eth.accounts[1], value: web3.toWei(1, "ether")}).should.be.fulfilled;
      await increaseTimeTo(duration.hours(2));
      await this.contract.withdraw({from: web3.eth.accounts[1]}).should.be.rejectedWith('revert');
     });

     it('should fail due to no deposit', async function () {
      await this.contract.withdraw({from: web3.eth.accounts[1]}).should.be.rejectedWith('revert');
     });
 
     it('should fail with max delay', async function () {
      await this.contract.deposit(87601,{from: web3.eth.accounts[1], value: web3.toWei(1, "ether")}).should.be.rejectedWith('revert');
     });

    });
    

})
