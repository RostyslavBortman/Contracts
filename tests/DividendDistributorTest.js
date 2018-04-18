var increaseTimeTo = require('./helpers/increaseTime');
var latestTime = require('./helpers/latestTime');
var ether = require('./helpers/ether');
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


const RicoToken = artifacts.require('RicoToken');
const DividendDistributor = artifacts.require("DividendDistributor");
const PreSale = artifacts.require("PreSale");


contract('DividendDistributor', function ([_, owner, investor, wallet]) {
    
    const minimumInvest = 10000;

    before(async function () {
    // Advance to the next block to correctly read time in the solidity "now" function interpreted by ganache
    await advanceBlock();
    });

    beforeEach(async function () {
    this.startTimePreSale = latestTime() - duration.weeks(4);
    this.endTimePreSale = latestTime();
    this.periodPreSale = this.endTimePreSale - this.startTimePreSale;

    this.token =  await RicoToken.new();
    this.dividendDistributor = await DividendDistributor.new(this.token.address, { from: owner });
    this.preSale = await PreSale.new(
      this.startTimePreSale, this.periodPreSale, wallet, this.token.address, minimumInvest, { from: owner }
    );
    await this.token.addAdmin(this.dividendDistributor.address);
    await this.token.addAdmin(this.preSale.address);
    await this.preSale.sendTransaction({from: web3.eth.accounts[1], value: web3.toWei(1, "ether"), gas: "220000"});
    await this.dividendDistributor.sendTransaction({from: web3.eth.accounts[1], value: web3.toWei(6, "ether"), gas: "220000"});
  });

    describe('creating a valid DividendDistributor', function () {
     it('should fail with zero token address', async function () {
       DividendDistributor.new(0, { from: owner }
      ).should.be.rejectedWith('revert');
     });
    });

     describe('payable method', function () {

     it('should pass', async function () {
       this.token.addAdmin(this.dividendDistributor.address);
       this.dividendDistributor.sendTransaction({from: web3.eth.accounts[1], value: web3.toWei(1, "ether"), gas: "220000"}).should.be.fulfilled;
     });
   
    });

    describe('getDividend', function () {

     it('should pass due to dividend payments from first account', async function () {
       var balance;
       await this.token.balanceOf(web3.eth.accounts[1]).then(result => {
        balance = result;
       });
       assert.equal(await this.dividendDistributor.getDividend.call({from: web3.eth.accounts[1]}), true);
       await this.dividendDistributor.getDividend({from: web3.eth.accounts[1]});
       await this.token.transfer(web3.eth.accounts[3], balance, {from: web3.eth.accounts[1]});
       assert.equal(await this.dividendDistributor.getDividend.call({from: web3.eth.accounts[3]}), false);
     });

     it('should pass due to no dividend payments from first account', async function () {
       var balance;
       await this.token.balanceOf(web3.eth.accounts[1]).then(result => {
        balance = result;
       });
       await this.token.transfer(web3.eth.accounts[2], balance, {from: web3.eth.accounts[1]});
       assert.equal(await this.dividendDistributor.getDividend.call({from: web3.eth.accounts[2]}), true);
     });


     it('should pass', async function () {

       const investor1 = web3.eth.accounts[4];
       const investor2 = web3.eth.accounts[5];

       var balanceBefore1;
       var balanceBefore2;

       var balanceAfter1;
       var balanceAfter2;

       await this.preSale.sendTransaction({from: investor1, value: web3.toWei(1, "ether"), gas: "220000"}).should.be.fulfilled;
       await this.preSale.sendTransaction({from: investor2, value: web3.toWei(1, "ether"), gas: "220000"}).should.be.fulfilled;

       balanceBefore1 = await web3.eth.getBalance(investor1).toNumber();
       balanceBefore2 = await web3.eth.getBalance(investor2).toNumber();

       await this.dividendDistributor.getDividend({from: investor1});
       await this.dividendDistributor.getDividend({from: investor2});

       balanceAfter1 = await web3.eth.getBalance(investor1).toNumber();
       balanceAfter2 = await web3.eth.getBalance(investor2).toNumber();

       assert.equal(balanceBefore1 < balanceAfter1, true);
       assert.equal(balanceBefore2 < balanceAfter2, true);

     });
     


    });
    

})
