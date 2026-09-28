import { execFile } from "node:child_process";
import { existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";
import { config } from "./config.js";

const execFileAsync = promisify(execFile);
const repositoryRoot = fileURLToPath(new URL("..", import.meta.url));
const B002_ROLE = "nexus_command_tower_ro";
const B002_QUERY = "SELECT current_user, current_database();";
const now = () => new Date().toISOString();
const result = (system, state, summary, evidence) => ({ system, state, summary, evidence, observedAt: now() });

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
  const { postgresqlHost, postgresqlPort, postgresqlDatabase, postgresqlPassword, psqlPath } = config.verification;
  if (!postgresqlHost) return result("PostgreSQL", "blocked", "B-002 not verified: no database host is configured; no authentication attempted.", "Set NEXUS_POSTGRES_HOST.");
  if (!postgresqlPassword) return result("PostgreSQL", "blocked", "B-002 not verified: no local database credential is configured; no authentication attempted.", "Set the local NEXUS_POSTGRES_PASSWORD without exposing it to the UI or logs.");

  try {
    const { stdout } = await execFileAsync(psqlPath, [
      "-X", "-w", "-A", "-t", "-F", "\t",
      "-h", postgresqlHost,
      "-p", String(postgresqlPort),
      "-d", postgresqlDatabase,
      "-U", B002_ROLE,
      "-c", B002_QUERY
    ], {
      cwd: repositoryRoot,
      env: {
        ...process.env,
        PGPASSWORD: postgresqlPassword,
        PGUSER: B002_ROLE,
        PGDATABASE: postgresqlDatabase,
        PGHOST: postgresqlHost,
        PGPORT: String(postgresqlPort)
      },
      timeout: 5000,
      windowsHide: true,
      maxBuffer: 2000
    });
    const [currentUser, currentDatabase] = stdout.trim().split("\t");
    if (currentUser !== B002_ROLE || !currentDatabase) {
      return result("PostgreSQL", "failed", "B-002 not verified: authenticated query returned an unexpected identity.", `Expected current_user=${B002_ROLE}; received current_user=${currentUser || "empty"}.`);
    }
    return result("PostgreSQL", "verified", `B-002 VERIFIED: authenticated as ${B002_ROLE} and read-only identity query succeeded.`, `current_user=${currentUser}; current_database=${currentDatabase}; query=${B002_QUERY}`);
  } catch (error) {
    return result("PostgreSQL", "failed", "B-002 not verified: authenticated read-only query failed.", `Authentication or query failure for role ${B002_ROLE}; no write was attempted.`);
  }
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
  return { generatedAt: now(), contract: "B-002 authenticated read-only PostgreSQL verification", checks };
}
