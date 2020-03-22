/*

MIMT = live.app2.biz

# 破解小视频次数和VIP限制
^https://live\.app2\.biz\/api\/public\/\?service\=User\.getBaseInfo* url script-response-body Dpsp.live.video.js

# 破解直播付费房间
^https://live\.app2\.biz\/api\/public\/\?service\=Live\.roomCharge url response-body code\"\:\d+ response-body code":0

*/

var json=$response.body;
var body=JSON.parse(json);
var Info=body.data.info;
Info[0]["vip_end_time"]="1900204271";
Info[0]["votes"]="999999.00";
Info[0]["vipvd"].type="1";
Info[0]["vipvd"].endtime="1900204271";
Info[0]["buys"]=999999;
Info[0]["coin"]="999999";
Info[0]["vip"].type="1";
Info[0]["vip"].endtime="1900204271";
Info[0]["look_free_time"]=999999;
json=JSON.stringify(body);
console.log(json);
$done(json);

