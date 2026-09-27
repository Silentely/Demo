addEventListener('fetch', event => {
    event.respondWith(postWeChatUrl(event.request))
})

async function gatherResponse(response) {
  const { headers } = response
  const contentType = headers.get("content-type") || ""
  if (contentType.includes("application/json")) {
    return JSON.stringify(await response.json())
  }
  else if (contentType.includes("application/text")) {
    return await response.text()
  }
  else if (contentType.includes("text/html")) {
    return await response.text()
  }
  else {
    return await response.text()
  }
}

async function postWeChatUrl(request) {
  // 优先从环境变量读取配置，或修改下列默认占位值
  const corpid = (typeof WX_CORPID !== 'undefined' ? WX_CORPID : '') || "YOUR_CORP_ID";
  const corpsecret = (typeof WX_CORPSECRET !== 'undefined' ? WX_CORPSECRET : '') || "YOUR_CORP_SECRET";
  const agentid = (typeof WX_AGENTID !== 'undefined' ? WX_AGENTID : '') || "1000002";
  const cf_worker = (typeof WX_WORKER_URL !== 'undefined' ? WX_WORKER_URL : '') || "https://your-worker.workers.dev/";
  const touser = (typeof WX_TOUSER !== 'undefined' ? WX_TOUSER : '') || "@all";

  const url = `https://qyapi.weixin.qq.com/cgi-bin/gettoken?corpid=${corpid}&corpsecret=${corpsecret}`;

  const init = {
    headers: {
      "content-type": "application/json;charset=UTF-8",
    },
  }
  // 发出 get 请求获得 token
  const response = await fetch(url, init)
  const results = await gatherResponse(response)
  var jsonObj = JSON.parse(results)
  // 从 cf worker 请求提取发送内容
  var url2 = new URL(request.url);
  var form = url2.searchParams.get('form')
  var reg = new RegExp('%23', "g")
  var content = decodeURI(request.url.replace(cf_worker + "?form=" + form + "&content=", "")).replace(reg, "#")

  var key = jsonObj["access_token"]
  var wechat_work_url = "https://qyapi.weixin.qq.com/cgi-bin/message/send?access_token=" + key;
  var content_text;

  switch(form) {
    case "text":
        if (!content) {
            return new Response('content内容为空，请重新发送！', { status: 200 });
        }
        var template = {
          "touser": touser,
          "msgtype": "text",
          "agentid": agentid,
          "text": {
            "content": content
          },
          "safe": 0,
          "enable_id_trans": 0,
          "enable_duplicate_check": 0,
          "duplicate_check_interval": 1800
        }
        const init21 = {
          body: JSON.stringify(template),
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
        }
        const response10 = await fetch(wechat_work_url, init21)
        return response10;

    case "photo":
        if (!content) {
            return new Response('content内容为空，请重新发送！', { status: 200 });
        }
        var templatePhoto = {
          "touser" : touser,
          "toall" : 0,
          "msgtype" : "image",
          "agentid" : agentid,
          "image" : {
               "media_id" : content
          },
          "safe": 0
        }
        const init22 = {
          body: JSON.stringify(templatePhoto),
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
        }
        const response12 = await fetch(wechat_work_url, init22)
        return response12;

    case "video":
        if (!content) {
            return new Response('content内容为空，请重新发送！', { status: 200 });
        }
        content_text = content.split("|")
        var templateVideo = {
          "touser" : touser,
          "toall" : 0,
          "msgtype" : "video",
          "agentid" : agentid,
          "video" : {
               "media_id" : content_text[0],
               "title" : content_text[1],
               "description" : content_text[2]
          },
          "safe": 0
        }
        const init3 = {
          body: JSON.stringify(templateVideo),
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
        }
        const response13 = await fetch(wechat_work_url, init3)
        return response13;

    case "voice":
        if (!content) {
            return new Response('content内容为空，请重新发送！', { status: 200 });
        }
        var templateVoice = {
          "touser" : touser,
          "toall" : 0,
          "msgtype" : "voice",
          "agentid" : agentid,
          "voice" : {
               "media_id" : content
          }
        }
        const init23 = {
          body: JSON.stringify(templateVoice),
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
        }
        const response14 = await fetch(wechat_work_url, init23)
        return response14;

    case "textcard":
        if (!content) {
            return new Response('content内容为空，请重新发送！', { status: 200 });
        }
        content_text = content.split("|")
        var templateCard = {
          "touser" : touser,
          "toall" : 0,
          "msgtype" : "textcard",
          "agentid" : agentid,
          "textcard" : {
               "title" : content_text[0],
               "description" : content_text[1],
               "url" : content_text[2]
          }
        }
        const init4 = {
          body: JSON.stringify(templateCard),
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
        }
        const response15 = await fetch(wechat_work_url, init4)
        return response15;

    case "file":
        if (!content) {
            return new Response('content内容为空，请重新发送！', { status: 200 });
        }
        var templateFile = {
          "touser" : touser,
          "toall" : 0,
          "msgtype" : "file",
          "agentid" : agentid,
          "file" : {
               "media_id" : content
          },
          "safe": 0,
          "enable_duplicate_check": 0,
          "duplicate_check_interval": 1800,
          "enable_id_trans": 0
        }
        const init6 = {
          body: JSON.stringify(templateFile),
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
        }
        const response17 = await fetch(wechat_work_url, init6)
        return response17;

    case "markdown":
        if (!content) {
            return new Response('content内容为空，请重新发送！', { status: 200 });
        }
        var templateMd = {
          "touser" : touser,
          "toall" : 0,
          "msgtype" : "markdown",
          "agentid" : agentid,
          "markdown": {
               "content": content
          }
        }
        const init7 = {
          body: JSON.stringify(templateMd),
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
        }
        const response18 = await fetch(wechat_work_url, init7)
        return response18;

    case "photo_text":
        if (!content) {
            return new Response('content内容为空，请重新发送！', { status: 200 });
        }
        content_text = content.split("|")
        var templateNews = {
          "touser" : touser,
          "toall" : 0,
          "msgtype" : "news",
          "agentid" : agentid,
          "news" : {
             "articles" : [
                 {
                     "title" : content_text[0],
                     "description" : content_text[1],
                     "url" : content_text[2],
                     "picurl" : content_text[3]
                 }
              ]
          }
        }
        const init8 = {
          body: JSON.stringify(templateNews),
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
        }
        const response19 = await fetch(wechat_work_url, init8)
        return response19;

    default:
        return new Response(form + '为不存在的格式，请重新发送！', {status: 200});
  }
}
