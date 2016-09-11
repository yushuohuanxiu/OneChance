pragma solidity ^0.4.1;
/* OneChanceCoin 是专用于 OneChance 活动合约的货币，与一元人民币1:1等价
   主办方提供web网页，用户可以在页面通过支付宝、微信等接口支付人民币兑换 OneChanceCoin
   主办方收到用户支付的人民币后，调用 mint 接口为用户发放 OneChanceCoin
   OneChanceCoin 可以在用户之间自由转移
   OneChanceCoin 的消费，只能由 OneChance 活动合约发起
   用户在参加 OneChance 活动时， OneChance 合约自动调用 OneChanceCoin 合约的 consume 方法扣减用户的 OneChanceCoin ,同时用户用 OneChanceCoin 兑换了中奖机会
*/
contract OneChanceCoin {
    
    // 代币名称
    string public name;
    // 代币符号
    string public symbol;
    // 代币单位小数点位数
    uint8 public decimals;
   
    // OneChance 活动主办方,只有主办方才有权发放 OneChanceCoin 给用户
    address public sponsor;
   
    // OneChance 活动只能合约地址,只有 OneChance 合约有权扣钱用户 OneChanceCoin
    address public oneChance;
 
    // 用户 OneChanceCoin 余额列表
    mapping (address => uint) public balanceOf;
    
    modifier onlySponsor() {
        if (msg.sender != sponsor) throw;
        _;
    }
    
    modifier onlyOneChance() {
        if (msg.sender != oneChance) throw;
        _;
    }
    
    event Transfer(address indexed from, address indexed receiver, uint value);
	event Mint(address indexed sponsor, address indexed receiver, uint value);
 
    /* 初始化 OneChanceCoin 合约时,将合同创建者设置为主办方
       初始化参数 _name=OneChanceCoin, _symbol=C, _decimals=0
    */
    function OneChanceCoin(string _name, string _symbol, uint8 _decimals) {
        sponsor = msg.sender;
        name = _name;
        symbol = _symbol;
    }
   
    /* 设置 OneChance 合约地址,只有主办方可以调用此方法，而且此方法只第一次调用生效 */
    function initOneChance(address _oneChance) onlySponsor {
        if (oneChance != 0) throw;
        oneChance = _oneChance;
    }
   
    /* 发放 OneChanceCoin ,只有主办方有权调用此方法
	   @param _orderid 用户在主办方购买 OneChanceCoin 时创建的订单，主办方根据 Mint 通知中的订单号参数确认是那一笔订单发放 OneChanceCoin 成功
	*/
    function mint(address _receiver, uint _value) onlySponsor returns (bool success) {
        if (balanceOf[_receiver] + _value < balanceOf[_receiver]) throw;
        balanceOf[_receiver] += _value;
		// 通知主办方 OneChanceCoin 发放成功
		Mint(msg.sender, _receiver, _value);
    }
   
    /* 消费 OneChanceCoin , OneChanceCoin 只能用于 OneChance 活动,因此只有 OneChance 合约有权调用此方法 */
    function consume(address _consumer, uint _value) onlyOneChance external returns (bool success) {
        if (balanceOf[_consumer] < _value) throw;
        balanceOf[_consumer] -= _value;
    }
 
    /* 发送, OneChanceCoin 允许在用户之间转移 */
    function transfer(address _receiver, uint _value) {
        if (balanceOf[msg.sender] < _value) throw;
        if (balanceOf[_receiver] + _value < balanceOf[_receiver]) throw;
        balanceOf[msg.sender] -= _value;
        balanceOf[_receiver] += _value;
        Transfer(msg.sender, _receiver, _value);
    }
   
}
