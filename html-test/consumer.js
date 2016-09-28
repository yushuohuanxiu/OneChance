// Chance 购买记录对象
var buyRecordMap = new Object();
var txMap = new Object();

// 用户购买记录，合约不在链上保存以用户为key的购买列表记录，用户购买记录尽量由用户自行保存在本地
var userBuyInfo = new Object();

function initConsumerEvent() {
	console.log("注册用户事件监听");
	// Chance购买成功通知
    onechance.BuyChance().watch(function(error, result){
        if (!error) {
            console.log("BuyChance Ok");
        	showAccount();
            prompt(result.args.consumer + " 购买Chance成功，商品编号 " + txMap[result.args.txIndex].goodsId + " 商品数量 " + txMap[result.args.txIndex].quantity);
            saveBuyInfo(result.args.txIndex, result.args.beginUserId)
        }
    });
    // 奖品Chance售罄，提交原始随机数种子通知
    onechance.NotifySubmitPlaintext().watch(function(error, result){
    	if (!error) {
    		console.log("receive NotifySubmitPlaintext");
    		prompt("奖品编号 " + result.args.goodsId + " Chance 已售罄，开始提交原始随机数种子");
    		submitPlaintext(result.args.goodsId);
    	}
    });
    // 原始随机数种子提交成功提示
    onechance.SubmitPlaintext().watch(function(error, result){
    	if (!error) {
    		console.log("SubmitPlaintext Ok");
    		prompt(result.args.consumer + " 提交原始随机数种子成功");
    	}
    });
    // 开奖通知
    onechance.NotifyWinnerResult().watch(function(error, result){
    	if (!error) {
    		console.log("receive NotifyWinnerResult");
    		prompt("奖品编号 " + result.args.goodsId + " 已开奖，中奖者编号 " + result.args.winner);
    	}
    });
    // 发送代币成功通知
    onechancecoin.Transfer().watch(function(error, result){
    	if (!error) {
    		console.log("Transfer Ok");
        	showAccount();
    		prompt(result.args.from + " 发送给 " + result.args.receiver + " 代币 " + result.args.value + "C 成功");
    	}
    });
}

// 查询奖品信息
function showGoodsInfo(goodsId) {
    var goods = onechance.goods.call(goodsId);
    $('.goodsName').text(goods[0]);
    $('.goodsAmt').text(goods[1]);
    $('.goodsDescription').text(goods[2]);
    $('.goodsAlreadySale').text(goods[3]);
    $('.goodsCiphertextsLength').text(goods[4]);
    $('.goodsPlaintextsLength').text(goods[5]);
    $('.goodsWinner').text(goods[6]);
	$('.goodsWinnerAddr').text(goods[7]);
}

// 购买Chance
function buyChance(addr, goodsId, quantity, plaintext) {
	var ciphertext = sha3(plaintext);
	console.log("buyChance:", addr, goodsId, quantity, plaintext, ciphertext);
	var tx = new Object();
	tx.addr = addr;
	tx.goodsId = goodsId;
	tx.quantity = quantity;
	tx.plaintext = plaintext;
	tx.ciphertext = ciphertext;
	txMap[txIndex] = tx;
	// 记录用户购买记录
	if (userBuyInfo[addr] == undefined) {
		userBuyInfo[addr] = new Array();
	}
	userBuyInfo[addr].push(tx);
	// 记录奖品购买记录
	if (buyRecordMap[goodsId] == undefined)
		buyRecordMap[goodsId] = new Array;
	buyRecordMap[goodsId].push(tx);
	
    web3.personal.unlockAccount(addr, accountsPassword);
	onechance.buyChance.sendTransaction(goodsId, quantity, ciphertext, txIndex++, {from: addr, gas: 10000000});
}

// 保存购买记录
function saveBuyInfo(txIndex, beginUserId) {
	var tx = txMap[txIndex];
	tx.beginUserId = beginUserId;
	delete txMap[txIndex];
}

// 提交原始随机数
function submitPlaintext(goodsId) {
	console.log("submitPlaintext:", goodsId);
	var buyRecordArr = buyRecordMap[goodsId];
	$.each(buyRecordArr, function(index, buyRecord) {
		web3.personal.unlockAccount(buyRecord.addr, accountsPassword);
		onechance.submitPlaintext.sendTransaction(buyRecord.goodsId, buyRecord.beginUserId, buyRecord.plaintext, txIndex++, {from: buyRecord.addr, gas: 10000000});
	});
	// 测试环境对稳定性不作要求，实际情况下 buyRecordMap 记录要等收到随机数提交成功通知后才可以删除
	delete buyRecordMap[goodsId];
}

// 奖品购买用户列表查询
function queryConsumers(goodsId) {
	$('#consumersTbodyDiv').empty();
	var userArr = new Array(); 
    var goods = onechance.goods.call(goodsId);
    for (var userId=1; userId<=goods[3]; userId++) {
    	var userInfoArr = onechance.user.call(goodsId, userId);
    	$('#consumersTbodyDiv').append('<tr><td>userId</td><td>userAddr</td><td>plaintext</td><td>ciphertext</td></tr>'
			.replace(/userId/, userId)
			.replace(/userAddr/, userInfoArr[0])
			.replace(/plaintext/, userInfoArr[2])
			.replace(/ciphertext/, userInfoArr[1]));
    }
    
}

function transfer(sender, receiver, value) {
	console.log("transfer:", sender, receiver, value);
	web3.personal.unlockAccount(sender, accountsPassword);
	onechancecoin.transfer.sendTransaction(receiver, value, {from: sender, gas: 10000000});
}


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
}

// 简化客户端 sha3 调用
function sha3(num) {
	return web3.sha3(leftPad(web3.toHex(num).slice(2), 64, 0), {encoding: 'hex'});
}
