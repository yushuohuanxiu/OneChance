// 当前用户代币余额
console.log("account 1 balance:", onechancecoin.balanceOf.call(eth.accounts[0]));
console.log("account 2 balance:", onechancecoin.balanceOf.call(eth.accounts[1]));
console.log("account 3 balance:", onechancecoin.balanceOf.call(eth.accounts[2]));

// 发放代币
personal.unlockAccount(eth.accounts[0], "test123456");
onechancecoin.mint.sendTransaction(eth.accounts[0], 1000, txIndex++, {from: eth.accounts[0], gas: 10000000});
onechancecoin.mint.sendTransaction(eth.accounts[1], 1001, txIndex++, {from: eth.accounts[0], gas: 10000000});
onechancecoin.mint.sendTransaction(eth.accounts[2], 1002, txIndex++, {from: eth.accounts[0], gas: 10000000});
miner.start(1); admin.sleepBlocks(1); miner.stop();
console.log("account 1 balance", onechancecoin.balanceOf.call(eth.accounts[0]));
console.log("account 2 balance", onechancecoin.balanceOf.call(eth.accounts[1]));
console.log("account 3 balance", onechancecoin.balanceOf.call(eth.accounts[2]));

// 发布一个商品
personal.unlockAccount(eth.accounts[0], "test123456");
onechance.postGoods.sendTransaction("iphone7", 5, "sales", txIndex++, {from: eth.accounts[0], gas: 10000000});
miner.start(1); admin.sleepBlocks(1); miner.stop();

var topGoodsId = onechance.topGoodsId.call();
console.log("topGoodsId", topGoodsId);
console.log("Goods", topGoodsId, onechance.goods.call(topGoodsId));
