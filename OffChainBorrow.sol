pragma solidity ^0.4.19;
contract EthereumCourse {

 mapping (address => bool) private borrows;
 mapping (address => uint256) private borrowAmount;
 address private owner = msg.sender;

 string private message = "The amount of the loan is";
 string private error = "He has already borrow";

 event Result(string message, uint256 borrow);
 event DebtorValue(uint256 credit);
 event Error(string message);

 function getCredit(uint256 _borrowAmount) public returns(bool){
     if(!borrows[msg.sender]){
         borrows[msg.sender] = true;
         borrowAmount[msg.sender] = _borrowAmount;
         Result(message, _borrowAmount);
         return true;
     }
     Error(error);
     return false;
 }
 
 function returnCredit(uint256 _returnAmount, address _address) public returns(bool){
    if(msg.sender == owner && borrowAmount[_address] > 0){
        borrowAmount[_address] = borrowAmount[_address] - _returnAmount;
        Result("Rest of the borrow is", borrowAmount[_address]);
        return true;
    } else {
         Error("This address don't have any credit");
         return false;
    }
 }

 function isDebtor(address _address) public returns(bool){
    if(borrows[_address]){
        DebtorValue(borrowAmount[_address]);
        return true;
    } else{
        return false;
    }
 }


}