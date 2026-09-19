# B-000 Startup — Nexus Command Tower

## Purpose

Run the B-000 Command Tower scaffold locally. This release is limited to frontend routing, backend static serving, configuration, project structure, placeholder pages, and inert connector declarations.

## Local run

Requirements: Node.js 20 or later.

```bash
cp .env.example .env
npm start
```

Open http://localhost:8080.

For development with automatic server restart:

```bash
npm run dev
```

## Docker run

```bash
docker compose up --build
```

Open http://localhost:8080.

## B-000 boundary

No live PostgreSQL, GitHub, Airtable, n8n, Google Drive, or Nexus Capital Tracker connection exists. No SQL, telemetry, automation, business logic, or credential handling is included.
