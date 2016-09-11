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
    function mint(address _receiver, uint _value) onlySponsor {
        if (balanceOf[_receiver] + _value < balanceOf[_receiver]) throw;
        balanceOf[_receiver] += _value;
		// 通知主办方 OneChanceCoin 发放成功
		Mint(msg.sender, _receiver, _value);
    }
   
    /* 消费 OneChanceCoin , OneChanceCoin 只能用于 OneChance 活动,因此只有 OneChance 合约有权调用此方法 */
    function consume(address _consumer, uint _value) onlyOneChance external returns (bool success) {
        if (balanceOf[_consumer] < _value) throw;
        balanceOf[_consumer] -= _value;
        return true;
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

contract OneChance {
   
    // 活动主办方
    address public sponsor;
    
    // 代币合约
    OneChanceCoin public oneChanceCoin;
    
    struct Goods {
        string name; // 奖品名称
        uint amt; // 奖品价格
        string description; // 奖品描述
        address[] consumerArr; // 购买了 Chance 的用户列表
        bytes32[] ciphertextArr; // 用户购买 Chance 时提交的 sha256(随机数)
        uint[] plaintextArr; // Chance 售罄后通知用户提交的 随机数
        uint winner; // 中奖用户，等于 sum(所有用户随机数)%amt
    }
    
    // 商品列表
    mapping (uint => Goods) public goodsMap;
    uint public topGoodsIndex;
    
    modifier onlySponsor() {
        if (msg.sender != sponsor) throw;
        _;
    }
    
    event PostGoods(address indexed sponsor, string name, uint amt, string description, uint goodsId); // 商品发布成功通知
	event BuyChance(address indexed consumer, uint goodsId, uint quantity); // 购买Chance成功通知
	event NotifySubmitPlaintext(address indexed consumer, uint goodsId, uint userId, bytes32 ciphertext); // 提交随机数明文通知
	event SubmitPlaintext(address indexed consumer, uint goodsId, uint userId); // 随机数明文提交成功通知
   
    // 初始化,将合同创建者设置为主办方
    function OneChance() {
        sponsor = msg.sender;
    }
    
    // 初始化代币合约地址,只有主办方可以调用,而且只可以调用一次
    function initOneChanceCoin(address _address) onlySponsor {
        if (address(oneChanceCoin) != 0) throw;
        oneChanceCoin = OneChanceCoin(_address);
    }
   
    // 发布奖品,只有主办方可以调用
    function postGoods(string _name, uint _amt, string _description) onlySponsor returns (bool) {
        topGoodsIndex += 1;
        goodsMap[topGoodsIndex] = Goods({name:_name, amt:_amt, description:_description, consumerArr: new address[](_amt), ciphertextArr: new bytes32[](_amt), plaintextArr: new uint[](_amt), winner:0});
        // 通知主办方发布成功
        PostGoods(msg.sender, _name, _amt, _description, topGoodsIndex);
        return true;
    }
   
    // 购买 Chance
    function buyChance(uint _goodsId, bytes32[] _ciphertextArr) returns (bool) {
        if (goodsMap[_goodsId].consumerArr.length + _ciphertextArr.length > goodsMap[_goodsId].amt) throw;
        for (uint i=0; i<_ciphertextArr.length; i++) {
            if (sha256(0) == _ciphertextArr[1]) throw;
        }
       
        // 扣减用户 ChanceCoin
        oneChanceCoin.consume(msg.sender, _ciphertextArr.length);
        
        // 记录商品的购买用户
        for (i=0; i<_ciphertextArr.length; i++) {
            goodsMap[_goodsId].consumerArr.push(msg.sender);
            goodsMap[_goodsId].ciphertextArr.push(_ciphertextArr[i]);
        }
        
        // 通知用户购买成功
        BuyChance(msg.sender, _goodsId, _ciphertextArr.length);
        // 如果商品 Chance 已售罄，通知购买用户提交原始随机数以生成中奖用户
        if (goodsMap[_goodsId].consumerArr.length == goodsMap[_goodsId].amt) {
            notify(_goodsId);
        }
        return true;
    }
    
    // 通知用户提交原始随机数
    function notify(uint _goodsId) private {
        for (uint i=0; i<goodsMap[_goodsId].consumerArr.length; i++) {
            NotifySubmitPlaintext(goodsMap[_goodsId].consumerArr[i], _goodsId, i, goodsMap[_goodsId].ciphertextArr[i]);
        }
    }
    
    // 提交原始随机数,随机数应在 1-amt 中取值，避免超过 uint 表示范围
    function submitPlaintext(uint _goodsId, uint _userId, uint _plaintext) {
        if (_plaintext > goodsMap[_goodsId].amt) throw;
        if (goodsMap[_goodsId].plaintextArr[_userId] != 0) {
            SubmitPlaintext(msg.sender, _goodsId, _userId);
            throw;
        }
        if (sha256(_plaintext) != goodsMap[_goodsId].ciphertextArr[_userId]) throw;
        
        goodsMap[_goodsId].plaintextArr[_userId] = _plaintext;
        SubmitPlaintext(msg.sender, _goodsId, _userId);
        
        uint winner;
        for (uint i=0; i<goodsMap[_goodsId].amt; i++) {
            if (goodsMap[_goodsId].plaintextArr[i] == 0) {
                return;
            } else {
                winner += goodsMap[_goodsId].plaintextArr[i];
            }
        }
        
        // 计算中奖用户
        goodsMap[_goodsId].winner = winner % goodsMap[_goodsId].amt;
        
    }
    
    function getGoods(uint _index) returns (string name, uint amt, string description, uint winner, address[] consumerArr, bytes32[] ciphertextArr, uint[] plaintextArr) {
        name = goodsMap[_index].name;
        amt = goodsMap[_index].amt;
        description = goodsMap[_index].description;
        winner = goodsMap[_index].winner;
        consumerArr = goodsMap[_index].consumerArr;
        ciphertextArr = goodsMap[_index].ciphertextArr;
        plaintextArr = goodsMap[_index].plaintextArr;
    }
    
    function getGoodsInfo(uint _index) returns (string name, uint amt, string description, uint alreadySale, uint winner) {
        name = goodsMap[_index].name;
        amt = goodsMap[_index].amt;
        description = goodsMap[_index].description;
        alreadySale = goodsMap[_index].amt - goodsMap[_index].consumerArr.length;
        winner = goodsMap[_index].winner;
    }
}
