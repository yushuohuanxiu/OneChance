// 查询最终中奖结果
var goods = useronechance.goods.call(topGoodsId);
console.log("goods", topGoodsId, "info:", goods);

// 查询活动用户信息
for (var i=1; i<=goods[3]; i++) {
    console.log("consumer", i, "info:", useronechance.user.call(topGoodsId, i));
};
