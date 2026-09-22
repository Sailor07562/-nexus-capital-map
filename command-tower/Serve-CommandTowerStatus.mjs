import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const defaultPayloadPath = resolve(here, 'command-tower-status-payload.json');

function parseArgs(argv) {
  const args = new Map();
  for (let i = 0; i < argv.length; i += 1) {
    if (argv[i] === '--self-test') args.set('selfTest', true);
    if (argv[i] === '--payload' && argv[i + 1]) args.set('payload', resolve(argv[++i]));
    if (argv[i] === '--html' && argv[i + 1]) args.set('html', resolve(argv[++i]));
    if (argv[i] === '--host' && argv[i + 1]) args.set('host', argv[++i]);
    if (argv[i] === '--port' && argv[i + 1]) args.set('port', Number(argv[++i]));
  }
  return args;
}

async function loadPayload(payloadPath) {
  const payload = JSON.parse(await readFile(payloadPath, 'utf8'));
  if (!['bounded-read-only-fixture', 'approved-bounded-live-readonly'].includes(payload.source_mode)) throw new Error('Unsupported payload source mode.');
  if (payload.read_only !== true || payload.write_capability !== false) throw new Error('Payload safety boundary failed.');
  if (payload.row_data_exported !== false || payload.writes_attempted !== false) throw new Error('Payload export/write flags failed.');
  if (payload.view_count !== 8 || payload.summary_count !== 8) throw new Error('Approved view/summary counts failed.');
  if (payload.source_mode === 'approved-bounded-live-readonly' && (!Array.isArray(payload.summaries) || payload.summaries.length !== 8 || payload.summaries.some((summary) => summary.aggregate_only !== true))) {
    throw new Error('Aggregate-only summary boundary failed.');
  }
  return payload;
}

function sendJson(response, statusCode, body) {
  const encoded = JSON.stringify(body);
  response.writeHead(statusCode, {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
    'content-length': Buffer.byteLength(encoded),
  });
  response.end(encoded);
}

function sendHtml(response, html) {
  response.writeHead(200, {
    'content-type': 'text/html; charset=utf-8',
    'cache-control': 'no-store',
    'content-length': Buffer.byteLength(html),
  });
  response.end(html);
}

function createStatusServer(payload, html = null, payloadPath = null) {
  return createServer(async (request, response) => {
    if (request.method !== 'GET') {
      sendJson(response, 405, { error: 'method_not_allowed', read_only: true, write_capability: false });
      return;
    }
    let currentPayload = payload;
    if (payloadPath) {
      try {
        currentPayload = await loadPayload(payloadPath);
      } catch {
        sendJson(response, 500, { error: 'bounded_payload_unavailable', read_only: true, write_capability: false });
        return;
      }
    }
    if (request.url === '/healthz') {
      sendJson(response, 200, { status: 'ok', mode: currentPayload.source_mode, read_only: true, write_capability: false });
      return;
    }
    if (html && (request.url === '/' || request.url === '/CommandTower.html')) {
      sendHtml(response, html);
      return;
    }
    if (request.url === '/status') {
      sendJson(response, 200, currentPayload);
      return;
    }
    sendJson(response, 404, { error: 'not_found' });
  });
}

async function selfTest(payloadPath) {
  const payload = await loadPayload(payloadPath);
  const server = createStatusServer(payload);
  await new Promise((resolvePromise, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', resolvePromise);
  });
  const address = server.address();
  const base = `http://127.0.0.1:${address.port}`;
  try {
    const health = await fetch(`${base}/healthz`);
    const healthBody = await health.json();
    if (health.status !== 200 || healthBody.status !== 'ok' || healthBody.write_capability !== false) throw new Error('healthz check failed.');
    const status = await fetch(`${base}/status`);
    const statusBody = await status.json();
    if (status.status !== 200 || statusBody.view_count !== 8 || statusBody.summary_count !== 8) throw new Error('status check failed.');
    if (statusBody.row_data_exported !== false || statusBody.writes_attempted !== false || statusBody.write_capability !== false) throw new Error('status safety flags failed.');
    const writeAttempt = await fetch(`${base}/status`, { method: 'POST' });
    if (writeAttempt.status !== 405) throw new Error('write method was not rejected.');
    const missing = await fetch(`${base}/unknown`);
    if (missing.status !== 404) throw new Error('unknown path was not rejected.');
    console.log('PASS: local read-only status endpoint self-test passed.');
  } finally {
    await new Promise((resolvePromise) => server.close(resolvePromise));
  }
}

const args = parseArgs(process.argv.slice(2));
const payloadPath = args.get('payload') ?? defaultPayloadPath;
if (args.get('selfTest')) {
  await selfTest(payloadPath);
} else {
  const payload = await loadPayload(payloadPath);
  const htmlPath = args.get('html') ?? resolve(here, 'CommandTower.html');
  const html = await readFile(htmlPath, 'utf8');
  const server = createStatusServer(payload, html, payloadPath);
  const host = args.get('host') ?? '127.0.0.1';
  const port = args.get('port') ?? 58883;
  server.listen(port, host, () => {
    const address = server.address();
    console.log(`Command Tower read-only status endpoint listening at http://${address.address}:${address.port}`);
    console.log('Endpoints: GET /healthz and GET /status. Write methods are rejected.');
  });
}
