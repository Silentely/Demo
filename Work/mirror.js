// 使用方法：docker pull 你的域名/mysql/mysql-server 或修改daemon.json文件替换registry-mirrors地址
'use strict'

const hub_host = 'registry-1.docker.io'
const auth_url = 'https://auth.docker.io'
const workers_url = 'https://自定义域名'
/**
* static files (404.html, sw.js, conf.js)
*/

/** @type {RequestInit} */
const PREFLIGHT_INIT = {
  // status: 204,
  headers: new Headers({
    'access-control-allow-origin': '*',
    'access-control-allow-methods': 'GET,POST,PUT,PATCH,TRACE,DELETE,HEAD,OPTIONS',
    'access-control-max-age': '1728000',
  }),
}

/**
* @param {any} body
* @param {number} status
* @param {Object<string, string>} headers
*/
function makeRes(body, status = 200, headers = {}) {
  headers['access-control-allow-origin'] = '*'
  return new Response(body, { status, headers })
}


/**
* @param {string} urlStr
*/
function newUrl(urlStr) {
  try {
    return new URL(urlStr)
  } catch (err) {
    return null
  }
}


addEventListener('fetch', e => {
  const ret = fetchHandler(e)
    .catch(err => makeRes('error: ' + err.stack + "\n", 502))
  e.respondWith(ret)
})


/**
* @param {FetchEvent} e
*/
async function fetchHandler(e) {
  const getReqHeader = (key) => e.request.headers.get(key);

  let url = new URL(e.request.url);

  // 修改 pre head get 请求
  // 是否含有 %2F ，用于判断是否具有用户名与仓库名之间的连接符
  // 同时检查 %3A 的存在
  if (!/%2F/.test(url.search) && /%3A/.test(url.toString())) {
    let modifiedUrl = url.toString().replace(/%3A(?=.*?&)/, '%3Alibrary%2F');
    url = new URL(modifiedUrl);
    console.log(`handle_url: ${url}`)
  }

  if (url.pathname === '/token') {
    let token_parameter = {
      headers: {
        'Host': 'auth.docker.io',
        'User-Agent': getReqHeader("User-Agent"),
        'Accept': getReqHeader("Accept"),
        'Accept-Language': getReqHeader("Accept-Language"),
        'Accept-Encoding': getReqHeader("Accept-Encoding"),
        'Connection': 'keep-alive',
        'Cache-Control': 'max-age=0'
      }
    };
    let token_url = auth_url + url.pathname + url.search
    return fetch(new Request(token_url, e.request), token_parameter)
  }

  // 修改 head 请求
  if (/^\/v2\/[^/]+\/[^/]+\/[^/]+$/.test(url.pathname) && !/^\/v2\/library/.test(url.pathname)) {
    url.pathname = url.pathname.replace(/\/v2\//, '/v2/library/');
    console.log(`modified_url: ${url.pathname}`)
  }

  url.hostname = hub_host;

  let parameter = {
    headers: {
      'Host': hub_host,
      'User-Agent': getReqHeader("User-Agent"),
      'Accept': getReqHeader("Accept"),
      'Accept-Language': getReqHeader("Accept-Language"),
      'Accept-Encoding': getReqHeader("Accept-Encoding"),
      'Connection': 'keep-alive',
      'Cache-Control': 'max-age=0'
    },
    cacheTtl: 3600
  };

  if (e.request.headers.has("Authorization")) {
    parameter.headers.Authorization = getReqHeader("Authorization");
  }

  let original_response = await fetch(new Request(url, e.request), parameter)
  let original_response_clone = original_response.clone();
  let original_text = original_response_clone.body;
  let response_headers = original_response.headers;
  let new_response_headers = new Headers(response_headers);
  let status = original_response.status;

  if (new_response_headers.get("Www-Authenticate")) {
    let auth = new_response_headers.get("Www-Authenticate");
    let re = new RegExp(auth_url, 'g');
    new_response_headers.set("Www-Authenticate", response_headers.get("Www-Authenticate").replace(re, workers_url));
  }
  if (new_response_headers.get("Docker-Distribution-Api-Version")){
    new_response_headers.delete("Docker-Distribution-Api-Version");
  }

  if (new_response_headers.get("Location")) {
    return httpHandler(e.request, new_response_headers.get("Location"))
  }
  if (status === 404){
    original_text = "";
  }
  let response = new Response(original_text, {
    status,
    headers: new_response_headers
  })
  return response;

}


/**
* @param {Request} req
* @param {string} pathname
*/
function httpHandler(req, pathname) {
  const reqHdrRaw = req.headers

  // preflight
  if (req.method === 'OPTIONS' &&
    reqHdrRaw.has('access-control-request-headers')
  ) {
    return new Response(null, PREFLIGHT_INIT)
  }

  let rawLen = ''

  const reqHdrNew = new Headers(reqHdrRaw)

  const refer = reqHdrNew.get('referer')

  let urlStr = pathname

  const urlObj = newUrl(urlStr)

  /** @type {RequestInit} */
  const reqInit = {
    method: req.method,
    headers: reqHdrNew,
    redirect: 'follow',
    body: req.body
  }
  return proxy(urlObj, reqInit, rawLen)
}


/**
*
* @param {URL} urlObj
* @param {RequestInit} reqInit
*/
async function proxy(urlObj, reqInit, rawLen) {
  const res = await fetch(urlObj.href, reqInit)
  const resHdrOld = res.headers
  const resHdrNew = new Headers(resHdrOld)

  // verify
  if (rawLen) {
    const newLen = resHdrOld.get('content-length') || ''
    const badLen = (rawLen !== newLen)

    if (badLen) {
      return makeRes(res.body, 400, {
        '--error': `bad len: ${newLen}, except: ${rawLen}`,
        'access-control-expose-headers': '--error',
      })
    }
  }
  const status = res.status
  resHdrNew.set('access-control-expose-headers', '*')
  resHdrNew.set('access-control-allow-origin', '*')
  resHdrNew.set('Cache-Control', 'max-age=1500')

  resHdrNew.delete('content-security-policy')
  resHdrNew.delete('content-security-policy-report-only')
  resHdrNew.delete('clear-site-data')

  return new Response(res.body, {
    status,
    headers: resHdrNew
  })
}
