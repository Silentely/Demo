/*
 * https://hostloc.com/thread-805441-1-1.html
 */

const whitelist = ["/bot5xxxxxx:","/bot5xxxxxx58:","/bot5xxxxxxx9:","/bot5xxxxxx2:","/bot5xxxxx0:","/bot5xxxxxx8:","/bot5xxxxxx8:"];
const tg_host = "api.telegram.org";

addEventListener('fetch', event => {
    event.respondWith(handleRequest(event.request))
})

function validate(path) {
    for (var i = 0; i < whitelist.length; i++) {
        if (path.startsWith(whitelist[i]))
            return true;
    }
    return false;
}

async function handleRequest(request) {
    var u = new URL(request.url);
    u.host = tg_host;
    if (!validate(u.pathname))
        return new Response('Unauthorized', {
            status: 403
        });
    var req = new Request(u, {
        method: request.method,
        headers: request.headers,
        body: request.body
    });
    const result = await fetch(req);
    return result;
}
