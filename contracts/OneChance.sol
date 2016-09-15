pragma solidity ^0.4.1;

/* 地址压缩工具
 * 本合约作为基础设施，维护一份20byte地址数据到4byte无符号整数的双向映射
 * 如果某个合约需要存储大量重复地址信息(例如一元夺宝合约每一个商品都要存储所有购买用户的地址列表，不同商品的购买用户列表很大程度上是重复的)
 * 可以调用本合约将地址压缩为4byte后存储
 * 本合约只在用户第一次注册时消耗gas存储用户地址信息，之后用户address到uid的双向查询都不需要成本
 */
contract AddressCompress {
    
    mapping (address => uint32) public uidOf;
    mapping (uint32 => address) public addrOf;
    
    uint32 public topUid;
    
    function regist(address _addr) returns (uint32 uid) {
        if (uidOf[_addr] != 0) throw;
        uid = ++topUid;
        uidOf[_addr] = uid;
        addrOf[uid] = _addr;
    }
}
/* OneChanceCoin 是专用于 OneChance 活动合约的货币，与一元人民币1:1等价
 * 主办方提供web服务，用户可以在页面通过支付宝、微信等接口支付人民币兑换 OneChanceCoin
 * 主办方收到用户支付的人民币后，调用 mint 接口为用户发放 OneChanceCoin
 * OneChanceCoin 可以在用户之间自由转移
 * OneChanceCoin 的消费，只能由 OneChance 活动合约发起
 * 用户在参加 OneChance 活动时， OneChance 合约自动调用 OneChanceCoin 合约的 consume 方法扣减用户的 OneChanceCoin ,同时用户用 OneChanceCoin 兑换了中奖机会
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
    
    // 地址压缩合约地址，提供地址转换以压缩地址字段长度
    AddressCompress public addressCompress;
 
    // 用户 OneChanceCoin 余额列表
    // key 字段存储 4byes uid
    // value 字段存储 uint32 ,最大支持43亿左右余额
    mapping (uint32 => uint32) private balances;
    
    modifier onlySponsor() {
        if (msg.sender != sponsor) throw;
        _;
    }
    
    modifier onlyOneChance() {
        if (msg.sender != oneChance) throw;
        _;
    }
    
    event InitOneChance(); // OneChance 合约地址设置成功通知
    event Transfer(address indexed from, address indexed receiver, uint value);
    event Mint(address indexed receiver, uint value, uint txIndex);
 
    /* 初始化 OneChanceCoin 合约时,将合同创建者设置为主办方
     * 初始化参数 _name="ChanceCoin", _symbol="C", _decimals=0
     * 初始化参数 _addressCompress 传入地址压缩合约的地址
     */
    function OneChanceCoin(string _name, string _symbol, uint8 _decimals, address _addressCompress) {
        sponsor = msg.sender;
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        addressCompress = AddressCompress(_addressCompress);
    }
    
    function balanceOf(address _addr) returns (uint balance) {
        balance = balances[addressCompress.uidOf(_addr)];
    }
   
    /* 设置 OneChance 合约地址,只有主办方可以调用此方法，而且此方法只第一次调用生效 */
    function initOneChance(address _oneChance) onlySponsor {
        if (oneChance != 0) throw;
        oneChance = _oneChance;
        InitOneChance();
    }
   
    /* 发放 OneChanceCoin ,只有主办方有权调用此方法
     * 主办方使用 txIndex 在多笔发行操作时确认是哪一笔操作成功
     */
    function mint(address _receiver, uint32 _value, uint _txIndex) onlySponsor {
        // uidOf方法是否消耗gas,文档中没有找到明确描述,需要进一步实验
        // 如果uidOf消耗gas,建议将uid的查询交给用户的客户端自动使用call调用,用户与OneChanceCoin只使用uid交互
        uint32 uid = addressCompress.uidOf(_receiver);
        if (uid == 0)
            uid = addressCompress.regist(_receiver);
        
        if (balances[uid] + _value < balances[uid]) throw;
        balances[uid] += _value;
        // 通知 OneChanceCoin 发放成功
        Mint(_receiver, _value, _txIndex);
    }
   
    /* 消费 OneChanceCoin , OneChanceCoin 只能用于 OneChance 活动,因此只有 OneChance 合约有权调用此方法 */
    function consume(uint32 _consumerUid, uint32 _value) onlyOneChance external returns (bool success) {
        if (balances[_consumerUid] < _value) throw;
        balances[_consumerUid] -= _value;
        return true;
    }
 
    /* 发送, OneChanceCoin 允许在用户之间转移 */
    function transfer(address _receiver, uint32 _value) {
        uint32 senderUid = addressCompress.uidOf(msg.sender);
        if (senderUid == 0) throw;
        if (balances[senderUid] < _value) throw;
        uint32 receiverUid = addressCompress.uidOf(_receiver);
        if (receiverUid == 0)
            receiverUid = addressCompress.regist(_receiver);
        if (balances[receiverUid] + _value < balances[receiverUid]) throw;
        balances[senderUid] -= _value;
        balances[receiverUid] += _value;
        Transfer(msg.sender, _receiver, _value);
    }
   
}

/* 一元夺宝活动合约,主办方通过合约可以发布价值为amt的奖品,用户使用 OneChanceCoin 购买奖品的中奖 Chance ,每个用户可以购买1到多份 Chance
 * 每个奖品的中奖结果由所有用户参与生成,用户在购买 Chance 的同时提供对应数量的 sha3(随机数) ,通过sha3哈希后的摘要数据无法计算出原始值
 * 在奖品的全部 Chance 售罄后,合约会发送 event 事件给奖品的购买用户,购买用户收到事件通知后,需要提交购买 Chance 时提供的 随机数明文
 * 当奖品的所有购买用户随机数集齐,合约自动计算中奖用户 sum(所有用户随机数)%amt+1
 * 目前没有考虑用户恶意不提交原始随机数的情况(比如最后一个用户发现提交随机数后自己没有中奖,不提交自己正好可以中奖)
 * 后续优化方案可以考虑每个用户缴纳一定数量保证金,对不提交用户罚没保证金并退还其它用户购买金额
 * 或使用会员等级对应不同级别奖品等形式控制
 */
contract OneChance {
   
    // 活动主办方
    address public sponsor;
    
    // 代币合约
    OneChanceCoin public oneChanceCoin;
    
    // 地址压缩合约地址，提供地址转换以压缩地址字段长度
    AddressCompress public addressCompress;
    
    // 随机数种子对象
    struct RandomSeed {
        bytes32 ciphertext;
        uint32 plaintext;
    }
    
    // 奖品对象
    struct Goods {
        string name; // 奖品名称
        uint32 amt; // 奖品价格
        string description; // 奖品描述
        uint32 winnerId; // 中奖用户Id，等于 sum(所有用户随机数)%amt+1
        uint32 ciphertextsLength; // 用户提交的sha3(原始随机数种子)数量
        uint32 plaintextsLength; // 用户提交的原始随机数种子数量
        uint32[] consumers; // 购买用户列表,index+1=用户Id,存储内容为压缩地址uid
        mapping (uint32 => RandomSeed) randomSeeds; // 随机数种子
    }
    
    // 商品列表
    Goods[] private goodses;
    uint32 public topGoodsId;
    
    modifier onlySponsor() {
        if (msg.sender != sponsor) throw;
        _;
    }
    
    event InitOneChanceCoin(); // oneChanceCoin 合约地址设置成功通知
    event PostGoods(uint goodsId, uint txIndex); // 商品发布成功通知
    event BuyChance(address indexed consumer, uint beginUserId, uint txIndex); // 购买Chance成功通知
    event NotifySubmitPlaintext(uint goodsId); // 提交随机数明文通知
    event SubmitPlaintext(address indexed consumer, uint txIndex); // 随机数明文提交成功通知
    event NotifyWinnerResult(uint goodsId, uint winner);
   
    // 初始化,将合同创建者设置为主办方,同时初始化地址压缩与代币合约地址
    function OneChance(address _oneChanceCoin, address _addressCompress) {
        sponsor = msg.sender;
        oneChanceCoin = OneChanceCoin(_oneChanceCoin);
        addressCompress = AddressCompress(_addressCompress);
    }
    
    // 查询奖品信息
    function goods(uint32 _goodsId) returns (string name, uint32 amt, string description, uint consumersLength, uint32 ciphertextsLength, uint32 plaintextsLength, uint32 winnerId, address winnerAddr) {
        Goods goods = goodses[_goodsId];
        name = goods.name;
        amt = goods.amt;
        description = goods.description;
        consumersLength = goods.consumers.length;
        ciphertextsLength = goods.ciphertextsLength;
        plaintextsLength = goods.plaintextsLength;
        winnerId = goods.winnerId;
        if (winnerId!=0) {
            // 用户Id-1得到数组下标,然后用地址压缩合约查询uid得到用户实际地址
            winnerAddr = addressCompress.addrOf(goods.consumers[winnerId-1]);
        }
    }
    
    // 查询用户信息
    function user(uint32 _goodsId, uint32 _userId) returns (address userAddr, bytes32 ciphertext, uint32 plaintext) {
        userAddr = addressCompress.addrOf(goodses[_goodsId].consumers[_userId-1]);
        ciphertext = goodses[_goodsId].randomSeeds[_userId].ciphertext;
        plaintext = goodses[_goodsId].randomSeeds[_userId].plaintext;
    }
   
    // 发布奖品,只有主办方可以调用,主办方用 txIndex 确定多笔发布奖品操作具体哪一个奖品发布成功
    function postGoods(string _name, uint32 _amt, string _description, uint _txIndex) onlySponsor {
        Goods memory goods;
        goods.name = _name;
        goods.amt = _amt;
        goods.description = _description;
        topGoodsId++;
        goodses[topGoodsId] = goods;
        // 通知主办方发布成功
        PostGoods(topGoodsId, _txIndex);
    }
   
    // 购买 Chance ,同一用户多次购买同一 goods 的话,需要 txIndex 区分, sha3(随机数种子) 是可选参数
    function buyChance(uint32 _goodsId, uint32 _quantity, bytes32 _ciphertext, uint _txIndex) {
        Goods goods = goodses[_goodsId];
        if (goods.consumers.length + _quantity > goods.amt) throw;
        
        uint32 uid = addressCompress.uidOf(msg.sender);
       
        // 扣减用户 ChanceCoin
        oneChanceCoin.consume(uid, _quantity);
        
        // 通知用户购买成功，用户需要记录自己的 goodsId+beginUserId+plaintext ,提交原始随机数时需要
        BuyChance(msg.sender, goods.consumers.length+1, _txIndex);
        
        // 记录用户提交的sha3(随机数种子)
        if (_ciphertext != sha3(0)) {
            RandomSeed memory randomSeed;
            randomSeed.ciphertext = _ciphertext;
            goods.randomSeeds[uint32(goods.consumers.length+1)] = randomSeed;
        }
        
        // 记录商品的购买用户
        for (uint32 i=0; i<_quantity; i++) {
            goods.consumers.push(uid);
        }
        
        // 如果商品 Chance 已售罄，通知购买用户提交原始随机数以生成中奖用户
        if (goods.consumers.length == goods.amt) {
            NotifySubmitPlaintext(_goodsId);
        }
    }
    
    // 提交原始随机数
    function submitPlaintext(uint32 _goodsId, uint32 _userId, uint32 _plaintext, uint _txIndex) {
        Goods goods = goodses[_goodsId];
        if (goods.consumers.length != goods.amt) throw; // Chance 售罄前不允许提交随机数种子
        
        if (goods.randomSeeds[_userId].ciphertext == 0) throw; // 如果sha3(随机数种子)未提交过,不允许提交
        if (goods.randomSeeds[_userId].plaintext != 0) throw; // 如果随机数种子已提交过,不允许重复提交
        if (sha3(_plaintext) != goods.randomSeeds[_userId].ciphertext) throw; // 随机数种子与sha3结果不符
        
        // 保存随机数种子
        goods.randomSeeds[_userId].plaintext = _plaintext;
        goods.plaintextsLength++;
        SubmitPlaintext(msg.sender, _txIndex);
        
        if (goods.plaintextsLength == goods.ciphertextsLength) {
            uint random;
            for (uint32 i=0; i<goods.amt; i++) {
                random += goods.randomSeeds[_userId].plaintext;
            }
            // 计算中奖用户
            goods.winnerId = uint32(random % goods.amt + 1);
            // 通知用户中奖结果
            NotifyWinnerResult(_goodsId, goods.winnerId);
        }
        
    }

}
