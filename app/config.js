const port = Number.parseInt(process.env.NEXUS_COMMAND_TOWER_PORT || "8080", 10);

export const config = Object.freeze({
  host: process.env.NEXUS_COMMAND_TOWER_HOST || "0.0.0.0",
  port: Number.isInteger(port) && port > 0 ? port : 8080,
  applicationName: "Nexus Command Tower",
  mode: "live-status-verification",
  verification: Object.freeze({
    postgresqlHost: process.env.NEXUS_POSTGRES_HOST || "",
    postgresqlPort: Number.parseInt(process.env.NEXUS_POSTGRES_PORT || "5432", 10),
    n8nUrl: process.env.NEXUS_N8N_URL || "",
    trackerUrl: process.env.NEXUS_CAPITAL_TRACKER_URL || ""
  })
});
