import "OneChanceCoin.sol"
pragma solidity ^0.4.1;
contract OneChance {
    OneChanceCoin oneChanceCoin;
   
    /* OneChance 活动主办方,只有主办方才有权维护发布商品 */
    address public sponsor;
       
    struct Goods {
        string name; // 商品名称
        uint amt; // 商品价格
        string description; // 商品描述
        address[] userArr; // 购买了该商品 Chance 的用户列表
        uint winner; // 中奖用户
    }
   
    /* 商品列表 */
    Goods[] public goodsArr;
   
    /* 用户列表 */
    mapping (address => uint[][2]) public userMap;
    
    modifier onlySponsor() {
        if (msg.sender != sponsor) throw;
        _;
    }
    
    event PostGoods(address indexed sponsor, string name, uint amt, string description, uint goodsId);
	event BuyChance(address indexed consumer, uint goodsId, uint quantity);
	event LotteryDraw(address indexed receiver, uint goodsId, address winner); // 开奖结果通知 receiver 是 sponsor 与所有的 consumer
   
    /* 初始化 OneChance 合约时,将合同创建者设置为主办方 */
    function OneChance() {
        sponsor = msg.sender;
    }
    
    /* 初始化 OneChanceCoin 合约地址,只有主办方可以调用,而且只可以调用一次 */
    function initOneChanceCoin(address _address) onlySponsor {
        if (address(oneChanceCoin) != 0) throw;
        oneChanceCoin = OneChanceCoin(_address);
    }
   
    /* @dev 发布商品,只有主办方可以调用此方法
       @param _name 商品名称
       @param _amt 商品价格
       @param _description 商品描述
       @return id 商品id
    */
    function postGoods(string _name, uint _amt, string _description) onlySponsor {
        Goods memory goods;
        goods.name = _name;
        goods.amt = _amt;
        goods.description = _description;
        goodsArr.push(goods);
        // 通知主办方发布成功
        PostGoods(msg.sender, _name, _amt, _description, goodsArr.length-1);
    }
   
    /* @dev 购买商品
    */
    function buyChance(uint _goodsId, uint _quantity) {
        if (goodsArr[_goodsId].userArr.length + _quantity > goodsArr[_goodsId].amt) throw;
       
        // 扣减用户 ChanceCoin
        if (!oneChanceCoin.consume(msg.sender, _quantity)) throw;
       
        // 记录商品的购买用户
        for (uint i=1; i<=_quantity; i++) {
            goodsArr[_goodsId].userArr.push(msg.sender);
        }
        
        // 记录用户的购买商品
        bool flag = true;
        for (i=0; i<userMap[msg.sender].length; i++) {
            if (userMap[msg.sender][i][0] == _goodsId) {
                userMap[msg.sender][i][1] += _quantity;
                flag = false;
            }
        }
        if (flag) {
            userMap[msg.sender][i][0] = _goodsId;
            userMap[msg.sender][i][1] = _quantity;
        }
        
        // 通知用户购买成功
        BuyChance(msg.sender, _goodsId, _quantity);
        // 如果商品 Chance 已售罄，开始抽奖
        if (goodsArr[_goodsId].userArr.length == goodsArr[_goodsId].amt) {
            lotteryDraw(_goodsId);
        }
    }
   
    function lotteryDraw(uint _goodsId) private {
       
    }
}
