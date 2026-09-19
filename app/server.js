import { createReadStream, existsSync, statSync } from "node:fs";
import { createServer } from "node:http";
import { extname, join, normalize } from "node:path";
import { fileURLToPath } from "node:url";
import { config } from "./config.js";
import { collectLiveStatus } from "./live-status.js";

const here = fileURLToPath(new URL(".", import.meta.url));
const frontendRoot = join(here, "..", "frontend");
const contentTypes = {
  ".css": "text/css; charset=utf-8",
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".svg": "image/svg+xml"
};

function sendFile(response, filePath) {
  response.writeHead(200, { "content-type": contentTypes[extname(filePath)] || "application/octet-stream" });
  createReadStream(filePath).pipe(response);
}

const server = createServer(async (request, response) => {
  if (request.method !== "GET" && request.method !== "HEAD") {
    response.writeHead(405, { allow: "GET, HEAD" });
    response.end("Method not allowed");
    return;
  }

  const requestedPath = new URL(request.url, "http://localhost").pathname;
  if (requestedPath === "/api/live-status") {
    const status = await collectLiveStatus();
    response.writeHead(200, { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" });
    response.end(JSON.stringify(status));
    return;
  }
  const relativePath = requestedPath === "/" ? "index.html" : requestedPath.replace(/^\/+/, "");
  const filePath = normalize(join(frontendRoot, relativePath));
  const safePath = filePath.startsWith(frontendRoot) && existsSync(filePath) && statSync(filePath).isFile();

  if (safePath) {
    if (request.method === "HEAD") {
      response.writeHead(200, { "content-type": contentTypes[extname(filePath)] || "application/octet-stream" });
      response.end();
      return;
    }
    sendFile(response, filePath);
    return;
  }

  // SPA fallback: page routing is client-side only in B-000.
  sendFile(response, join(frontendRoot, "index.html"));
});

server.listen(config.port, config.host, () => {
  console.log(`${config.applicationName} B-001 verification listening on http://localhost:${config.port}`);
});
