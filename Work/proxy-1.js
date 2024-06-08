// 代码1
addEventListener(
  "fetch",event => {
     let url=new URL(event.request.url);
     url.hostname="xxx.xx.xxx"; // 修改需要反代的域名
     url.protocol='https'; // 如为http协议请修改为http
     let request=new Request(url,event.request);
     event. respondWith(
       fetch(request)
     )
  }
)

// 代码2
const hostname = "https://xxx.xx.xxx" // 需要反代的地址

function handleRequest(request) {
    let url = new URL(request.url);
    return fetch(new Request(hostname + url.pathname,request));
}

addEventListener("fetch"， event => {
  event.respondWith(handleRequest(event.request));
})
