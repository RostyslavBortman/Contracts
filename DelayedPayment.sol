contract DelayedPayment {

    mapping (address => uint) balances;
    mapping (address => uint256) delay;
    mapping (address => uint256) start;

    uint256 maxDelay = 87600;
    

    modifier canWithdraw(){
        require (balances[msg.sender] > 0 && now > start[msg.sender] + delay[msg.sender]);
        _;
    }

    function withdraw() canWithdraw public {
       msg.sender.transfer(balances[msg.sender]);
       balances[msg.sender] = 0;
    }

    function deposit(uint256 hour) external payable {
        require (hour > 0 && hour < maxDelay);
    
        balances[msg.sender] = balances[msg.sender] + msg.value;
        delay[msg.sender] = hour * 1 hours;
        start[msg.sender] = now;
    }

    // make delay for 1 hour by default
    function () external payable {
        balances[msg.sender] = balances[msg.sender] + msg.value;
        delay[msg.sender] = 1 hours;
        start[msg.sender] = now;
    }
    
}