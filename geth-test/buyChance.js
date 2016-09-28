// Solidity 语言的 sha3() 算法，对传入的 uint 类型参数做了长度填充，因此客户端在计算 sha3(随机数) 时需要先进行补0
function leftPad (str, len, ch) {
  str = str + '';
  len = len - str.length;
  if (len <= 0) return str;
  ch = ch + '';
  var pad = '';
  while (true) {
    if (len & 1) pad += ch;
    len >>= 1;
    if (len) ch += ch;
    else break;
  }
  return pad + str;
};

// 简化客户端 sha3 调用
function sha3(num) {
	return web3.sha3(leftPad(web3.toHex(num).slice(2), 64, 0), {encoding: 'hex'});
};

// 记录交易记录
var txMap = new Object();

// 以用户的身份购买商品
// 合约 abi 与 address 用户可以从活动官网或者合约 github 得到
var useronechanceContract = web3.eth.contract(onechanceContract.abi);
var useronechance = useronechanceContract.at(onechance.address);

//注册购买Chance成功通知，记录beginUserId
useronechance.BuyChance().watch(function(error, result){
	if (!error) {
		// 收到原始随机数提交通知后,将原始随机数提交到合约
		txMap[result.args.txIndex].beginUserId = result.args.beginUserId;
		console.log("BuyChance", result.args.txIndex, result.args.beginUserId);
	}
});

// 注册随机数提交通知事件
useronechance.NotifySubmitPlaintext().watch(function(error, result){
    if (!error) {
    	// 收到原始随机数提交通知后,将原始随机数提交到合约
		for (var txId in txMap) {
			personal.unlockAccount(txMap[txId].addr, "test123456");
			useronechance.submitPlaintext.sendTransaction(result.args.goodsId, txMap[txId].beginUserId, txMap[txId].plaintext, txIndex++, {from: txMap[txId].addr, gas: 10000000});
		}
    	console.log("NotifySubmitPlaintext:", result.args.goodsId);
		miner.start(1); admin.sleepBlocks(1); miner.stop();
	}
});

// 查询奖品信息
var topGoodsId = useronechance.topGoodsId.call();
console.log("topGoodsId", topGoodsId);
console.log("Goods", topGoodsId, onechance.goods.call(topGoodsId));

// 用户1购买1个 Chance
// 本 Demo 随机数使用js随机函数自动生成,因为js精度关系随机数种子最大值为1000000000000000
// 实际使用中建议随机数由用户手动添加,可以用真随机数网站提供的服务,也可以掷骰子等自己生成
// 不要使用值较小的原始随机数,避免被快速查表攻击
var plaintext = Math.floor(1000000000000000*Math.random())+1;
var ciphertext = sha3(plaintext);
txMap[txIndex] = {
	addr : eth.accounts[0],
	goodsId : topGoodsId,
	plaintext : plaintext,
	ciphertext : ciphertext
};
personal.unlockAccount(eth.accounts[0], "test123456");
useronechance.buyChance.sendTransaction(topGoodsId, 1, ciphertext, txIndex++, {from: eth.accounts[0], gas: 10000000});
miner.start(1); admin.sleepBlocks(1); miner.stop();
useronechance.goods.call(topGoodsId);

// 用户2购买2个 Chance
plaintext = Math.floor(1000000000000000*Math.random())+1;
ciphertext = sha3(plaintext);
txMap[txIndex] = {
	addr : eth.accounts[1],
	goodsId : topGoodsId,
	plaintext : plaintext,
	ciphertext : ciphertext
};
personal.unlockAccount(eth.accounts[1], "test123456");
useronechance.buyChance.sendTransaction(topGoodsId, 2, ciphertext, txIndex++, {from: eth.accounts[1], gas: 10000000});
miner.start(1); admin.sleepBlocks(1); miner.stop();
useronechance.goods.call(topGoodsId);

// 用户3购买剩余 Chance
var remain = useronechance.goods.call(topGoodsId)[1]-2-1;
plaintext = Math.floor(1000000000000000*Math.random())+1;
ciphertext = sha3(plaintext);
txMap[txIndex] = {
	addr : eth.accounts[2],
	goodsId : topGoodsId,
	plaintext : plaintext,
	ciphertext : ciphertext
};
personal.unlockAccount(eth.accounts[2], "test123456");
useronechance.buyChance.sendTransaction(topGoodsId, remain, ciphertext, txIndex++, {from: eth.accounts[2], gas: 10000000});
miner.start(1); admin.sleepBlocks(1); miner.stop();
console.log("Goods", topGoodsId, onechance.goods.call(topGoodsId));
