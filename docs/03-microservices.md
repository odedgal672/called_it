# Microservices Breakdown

> Status: decided
> Topic order: 3 of N

---

## Split Strategy

**Runtime pattern split** — services are divided by how they run, not by business domain. This keeps the service count low while preserving the meaningful separations: scheduled workers, event-driven consumers, and HTTP request/response services are genuinely different runtime patterns with different scaling and deployment needs.

---

## Services

### 1. API Gateway
**Role:** Single entry point for all client traffic. Validates JWTs and routes to the App Service.

- Public-facing — the only service exposed to the internet
- Validates JWT on every incoming request
- Attaches `X-User-Id` header to forwarded requests
- No database access, no business logic
- Rejects unauthenticated requests before they reach any service (except `/auth/*` routes)

---

### 2. App Service
**Role:** Handles all HTTP CRUD — users, auth, groups, matches, predictions, and leaderboard reads.

- Owns all request/response business logic
- The only service that performs general-purpose PostgreSQL writes
- Issues JWTs on `/auth/register` and `/auth/login`
- Reads leaderboard standings from `leaderboard_entries` (written by Scoring Worker)
- Does **not** publish to Kafka — purely synchronous HTTP

**Endpoints (high level):**
```
POST /auth/register
POST /auth/login
POST /auth/refresh

GET/POST /groups
POST /groups/join
GET /groups/:id/leaderboard

GET /tournaments
GET /tournaments/:id/matches

POST /predictions
GET /predictions
```

---

### 3. Ingestion Worker
**Role:** Polls the external VCT API on a schedule, detects match state changes, and publishes events to Kafka.

- Runs on a schedule (e.g. every 60s; more frequently during active matches)
- Compares API response against current `matches` table state
- Writes updated scores to `matches` table (`score_a`, `score_b`, `status`)
- Publishes Kafka events for meaningful state changes:
  - `match.started` — match went live
  - `map.completed` — a map finished, scores changed
  - `match.completed` — match is over, final score set
- Uses `external_id` on matches to correlate API data with DB rows
- Handles API inconsistencies gracefully — re-publishes events if a score correction is detected

**Owns (writes):** `matches` table

---

### 4. Scoring Worker
**Role:** Consumes Kafka events and runs the scoring pipeline — updates points and leaderboards in real time.

- Event-driven — no HTTP endpoints, no schedule
- Consumes: `map.completed`, `match.completed`
- On each event:
  1. Load all predictions for the affected match
  2. Recalculate points for each prediction using current match score
  3. Write updated `points_entries` rows
  4. Compute delta and update `leaderboard_entries` for each affected user+group+tournament
  5. On `match.completed`: flip `is_final = true` on all points entries for that match

**Owns (writes):** `points_entries`, `leaderboard_entries`

---

## Database Ownership

One shared PostgreSQL instance. Services are separated by code convention, not by separate databases.

| Service | Writes | Reads |
|---|---|---|
| API Gateway | — | — |
| App Service | users, groups, group_members, tournaments, teams, predictions | all |
| Ingestion Worker | matches | matches |
| Scoring Worker | points_entries, leaderboard_entries | predictions, matches |

> Treat table ownership as a hard rule even though the DB is shared. A service must never write to another service's tables.

---

## Architecture Diagram

```
                        Internet
                            │
                   ┌────────▼────────┐
                   │   API Gateway   │  JWT validation + routing
                   └────────┬────────┘
                            │ X-User-Id header
                   ┌────────▼────────┐
                   │   App Service   │  HTTP CRUD, auth, leaderboard reads
                   └────────┬────────┘
                            │
                    ┌───────▼────────┐
                    │   PostgreSQL   │  (shared, one RDS instance)
                    └───────┬────────┘
                            │
          ┌─────────────────┤
          │                 │
 ┌────────▼──────────┐      │
 │  Ingestion Worker │      │
 │  (polls ext. API) │      │
 └────────┬──────────┘      │
          │ Kafka events     │
          │ (map.completed,  │
          │  match.completed)│
 ┌────────▼──────────┐      │
 │  Scoring Worker   ├──────┘
 │  (Kafka consumer) │  writes points + leaderboard
 └───────────────────┘
```

---

## Key Design Decisions

| Decision | Choice | Reasoning |
|---|---|---|
| Split strategy | Runtime pattern | Fewer services, cleaner for one developer; real complexity (Kafka, workers) preserved |
| Auth ownership | App Service issues JWTs; Gateway validates | Gateway stays stateless; no DB access at gateway |
| Database | Shared PostgreSQL | Pragmatic; avoids distributed data complexity for one developer |
| Table ownership | Enforced by convention | Soft contract — services only write their own tables |
| Ingestion → Scoring | Via Kafka | Decouples workers; Scoring Worker retries independently if it falls behind |
