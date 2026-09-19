import { execFile } from "node:child_process";
import { existsSync } from "node:fs";
import net from "node:net";
import { promisify } from "node:util";
import { config } from "./config.js";

const execFileAsync = promisify(execFile);
const repositoryRoot = new URL("..", import.meta.url).pathname;
const now = () => new Date().toISOString();
const result = (system, state, summary, evidence) => ({ system, state, summary, evidence, observedAt: now() });

function probeTcp(host, port) {
  return new Promise((resolve) => {
    const socket = net.connect({ host, port });
    const timer = setTimeout(() => { socket.destroy(); resolve(false); }, 2500);
    socket.once("connect", () => { clearTimeout(timer); socket.end(); resolve(true); });
    socket.once("error", () => { clearTimeout(timer); resolve(false); });
  });
}

async function probeHttp(url) {
  try {
    const response = await fetch(url, { method: "HEAD", signal: AbortSignal.timeout(3000), redirect: "manual" });
    return response.status > 0;
  } catch { return false; }
}

async function repositoryStatus() {
  if (!existsSync(`${repositoryRoot}/.git`)) return result("GitHub repository", "failed", "Local checkout is not a Git repository.", "Expected .git directory was not found.");
  try {
    const [{ stdout: branch }, { stdout: remote }, { stdout: changes }] = await Promise.all([
      execFileAsync("git", ["branch", "--show-current"], { cwd: repositoryRoot }),
      execFileAsync("git", ["remote", "get-url", "origin"], { cwd: repositoryRoot }),
      execFileAsync("git", ["status", "--porcelain"], { cwd: repositoryRoot })
    ]);
    const changeCount = changes.trim() ? changes.trim().split("\n").length : 0;
    return result("GitHub repository", "verified", `Local ${branch.trim() || "detached"} checkout verified; ${changeCount} uncommitted change(s).`, `Origin: ${remote.trim()}`);
  } catch (error) { return result("GitHub repository", "failed", "Local repository metadata could not be read.", error.message); }
}

async function postgresStatus() {
  const { postgresqlHost, postgresqlPort } = config.verification;
  if (!postgresqlHost) return result("PostgreSQL", "blocked", "No host configured; no database probe attempted.", "Set NEXUS_POSTGRES_HOST for a TCP-only reachability check.");
  const reachable = await probeTcp(postgresqlHost, postgresqlPort);
  return result("PostgreSQL", reachable ? "verified" : "failed", reachable ? "TCP endpoint accepted a connection; no SQL was executed." : "TCP endpoint could not be reached; no SQL was executed.", `${postgresqlHost}:${postgresqlPort}`);
}

async function urlStatus(system, url, variable) {
  if (!url) return result(system, "blocked", "No verification URL configured; no request attempted.", `Set ${variable} for an unauthenticated HEAD reachability check.`);
  const reachable = await probeHttp(url);
  return result(system, reachable ? "verified" : "failed", reachable ? "Endpoint responded to a read-only HEAD probe." : "Endpoint did not respond to a read-only HEAD probe.", url);
}

export async function collectLiveStatus() {
  const checks = await Promise.all([
    Promise.resolve(result("Command Tower", "verified", "Node application is serving this verification response.", `Node ${process.version}`)),
    repositoryStatus(), postgresStatus(), urlStatus("n8n", config.verification.n8nUrl, "NEXUS_N8N_URL"),
    Promise.resolve(result("Airtable — LB Nexus_Sandbox_v1", "blocked", "No B-001 verification adapter is configured.", "No Airtable request, credential, or write was attempted.")),
    Promise.resolve(result("Google Drive", "blocked", "No B-001 verification adapter is configured.", "No Drive request, credential, or write was attempted.")),
    urlStatus("Nexus Capital Tracker", config.verification.trackerUrl, "NEXUS_CAPITAL_TRACKER_URL")
  ]);
  return { generatedAt: now(), contract: "B-001 read-only live-status verification", checks };
}
