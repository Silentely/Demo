#1
Deno.serve(async (req) => {
  const url = new URL(req.url)
  return fetch("https://api.openai.com" + url.pathname, {
    method: req.method,
    headers: {
      Authorization: req.headers.get('Authorization'),
      "Content-Type": req.headers.get('Content-Type')
    },
    body: req.body
  })
});

#2
const OPENAI_API_HOST = "api.openai.com";

Deno.serve(async (request) => {
  const url = new URL(request.url);
  url.host = OPENAI_API_HOST;

  const newRequest = new Request(url.toString(), {
    headers: request.headers,
    method: request.method,
    body: request.body,
    redirect: "follow",
  });
  return await fetch(newRequest);
});

#3
import { serve } from "https://deno.land/std@0.181.0/http/server.ts";

const OPENAI_API_HOST = "api.openai.com";

serve(async (request) => {
  const url = new URL(request.url);

  if (url.pathname === "/") {
    return fetch(new URL("./Readme.md", import.meta.url));
  }

  url.host = OPENAI_API_HOST;
  return await fetch(url, request);
});

#4
import { Server } from "https://deno.land/std/http/server.ts";

const TARGET = "https://api.openai.com";
const handler = async (request: Request) => {
  const url = new URL(request.url);
  const targetUrl = new URL(TARGET + url.pathname + url.search);

  return await fetch(targetUrl.toString(), {
    method: request.method,
    headers: request.headers,
    body: request.body,
  });
};

const server = new Server({ handler });
console.log("server listening on http://localhost:80");

await server.listenAndServe();
