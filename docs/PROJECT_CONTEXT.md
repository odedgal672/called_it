# CalledIt.gg — Project Context & Handoff

> Single source of truth for resuming work on this project.
> Update at the end of every session.
> Last updated: 2026-03-28

---

## What We're Building

**CalledIt.gg** is a VCT (Valorant Champions Tour) predictions league web app. Users join private groups, predict the map score of professional Valorant matches, and compete on leaderboards scoped to each VCT tournament.

The project is also a **deliberate learning exercise**. The owner is using it to learn AWS, PostgreSQL, microservices, and Kafka by building a real product.

---

## How We Work

**Design phase (complete):** One topic at a time. Claude explains options and trade-offs, asks the owner what they want, challenges choices with real downsides, then documents agreed decisions in `/docs/`. Never dump a full architecture unprompted.

**Implementation phase (next):** The owner picks tasks from `docs/09-build-plan.md` — some they implement themselves, some they ask Claude to implement. When asking Claude to implement a task, reference the task number (e.g. "implement task 0.1"). Claude should read the relevant docs before writing any code, never invent decisions that aren't documented, and ask if anything is unclear.

**When resuming a new session:** Read this file and any docs files relevant to the task at hand. The owner will tell you what they want to work on. Do not re-explain already-made decisions unless asked.

---

## Current State

### Design Topics

| Topic | Status | Doc |
|---|---|---|
| Core entities & user flows | Done | `docs/01-core-entities-and-flows.md` |
| Data model & schema | Done | `docs/02-data-model.md` |
| Microservices breakdown | Done | `docs/03-microservices.md` |
| Scoring logic | Done | `docs/04-scoring-logic.md` |
| Kafka event design | Done | `docs/05-kafka-event-design.md` |
| External API integration | Done | `docs/06-external-api-integration.md` |
| AWS infrastructure | Done | `docs/07-aws-infrastructure.md` |
| API design | Done | `docs/08-api-design.md` |
| Build plan | Done | `docs/09-build-plan.md` |
| Frontend design | Not started — deferred until backend is built |

### Build Progress

No implementation has started. All 81 tasks in `docs/09-build-plan.md` are pending.
Next task to start: **0.1 — Initialize Maven monorepo with parent `pom.xml`**

---

## Full Tech Stack

| Layer | Technology | Reasoning |
|---|---|---|
| Language | Java | Owner's choice for learning backend microservices |
| Framework | Spring Boot | Industry standard for Java microservices; extensive ecosystem |
| Build tool | Maven | Better documented than Gradle for Spring Boot; more learning resources |
| Project structure | Monorepo (5 Maven modules) | Easier code sharing, one CI pipeline, simpler for one developer |
| Database | PostgreSQL on AWS RDS | Relational data model; strong consistency for live scoring |
| Kafka | Amazon MSK | Managed Kafka; focus on concepts not operations |
| Compute | AWS ECS Fargate | Right fit for 4 services; no Kubernetes overhead |
| Container registry | AWS ECR | Native ECS integration |
| Load balancer | AWS ALB | Public entry point; routes to API Gateway service |
| Secrets | AWS Secrets Manager | DB credentials and JWT secret; never in plaintext |
| DB migrations | Flyway | Standard Java migration tool; integrates with Spring Boot |
| Testing | JUnit 5 + Testcontainers | Real PostgreSQL in tests; no mocking the DB |
| CI/CD | GitHub Actions | Build, test, push to ECR, deploy to ECS on merge to main |

---

## Monorepo Module Structure

```
called-it/
  pom.xml                  ← parent POM (shared dependency versions)
  shared/                  ← Kafka event classes, shared enums
  api-gateway/             ← Spring Cloud Gateway, JWT validation, routing
  app-service/             ← all HTTP CRUD, auth, leaderboard reads
  ingestion-worker/        ← external API polling, Kafka producer
  scoring-worker/          ← Kafka consumer, scoring pipeline
```

---

## The 4 Services

| Service | Type | Owns (writes) | Pattern |
|---|---|---|---|
| API Gateway | Always-on ECS service | Nothing | HTTP proxy + JWT validation |
| App Service | Always-on ECS service | users, groups, group_members, tournaments, teams, predictions | HTTP CRUD |
| Ingestion Worker | Scheduled ECS task | matches | Polls VLR.gg, publishes Kafka events |
| Scoring Worker | Always-on ECS service | points_entries, leaderboard_entries | Kafka consumer |

All services share one PostgreSQL database. Table ownership is enforced by convention — a service never writes to another service's tables.

---

## All Finalized Decisions

### Product

| Decision | Choice | Reasoning |
|---|---|---|
| Prediction type | Map score only (e.g. 2-1 in BO3) | Winner inferred from score; no redundant input |
| Match formats | BO3 and BO5 | Standard VCT formats; valid scores differ per format |
| Prediction scope | Per user + match + **group** | Users in multiple groups predict independently per group |
| Prediction lock | At match start (`status = live`) | No changes after kickoff |
| Groups | Private, invite-only | No public discovery; join via invite code |
| Group membership | User can join multiple groups | Same user, independent leaderboard per group |
| Tournament scoping | Leaderboards scoped per tournament | One leaderboard per group per tournament |
| Prediction visibility | Hidden until match is live | Prevents copying; 403 if match is still upcoming |

### Scoring

| Decision | Choice | Reasoning |
|---|---|---|
| Points — correct winner | 1 pt | Base points for predicting the right team |
| Points — exact score bonus | +2 pts | Awarded on top of winner points when match ends |
| Points — exact score total | 3 pts | Exact score is 3x winner-only |
| Points structure | Additive | Exact score builds on winner points |
| Tied match (e.g. 1-1) | 0 points | No winner yet |
| Scoring trigger | After every map completion | Automatic, no manual confirmation |
| Points finalization | On match end (`is_final = true`) | Locked permanently; no manual step |
| Live scoring logic | Current map score treated as final | Recalculate after each map using same algorithm |

### Scoring Algorithm

```
function calculatePoints(match, prediction):
  if match.score_a == match.score_b: return 0

  current_leader = 'a' if match.score_a > match.score_b else 'b'
  predicted_winner = 'a' if prediction.score_a > prediction.score_b else 'b'

  if current_leader != predicted_winner: return 0

  points = 1  // correct winner

  if match.status == 'completed':
    if prediction.score_a == match.score_a and prediction.score_b == match.score_b:
      points += 2  // exact score bonus

  return points
```

### Architecture

| Decision | Choice | Reasoning |
|---|---|---|
| Microservices split | Runtime pattern (4 services) | Fewer services; real Kafka/async complexity preserved |
| Database | One shared PostgreSQL | Pragmatic; avoids distributed data complexity for one developer |
| Auth | App Service issues JWTs; API Gateway validates | Gateway stays stateless and DB-free |
| Session model | Short-lived JWT + refresh token | Stateless; works across all services |
| Internal trust | `X-User-Id` header, VPC-only traffic | Services only accept traffic from inside private network |
| Kafka topic | One topic: `match-scoring-events` | Preserves event ordering per match |
| Kafka partition key | `match_id` | All events for same match → same partition → guaranteed order |
| Kafka event style | Fat events (full match state in payload) | Scoring Worker needs no extra DB query for match state |
| External API | VLR.gg via `ExternalMatchDataProvider` interface | Unblocks dev; swap to Riot API later without changing ingestion logic |
| Live polling | 15s ± 3s jitter, only when matches are `live` | Near real-time; low enough to avoid rate limiting |
| Schedule polling | Every 10 minutes | Bootstraps and refreshes tournament/team/match data |
| API downtime | Retry with backoff; catch up on recovery | Correct eventual state guaranteed; leaderboard self-heals |
| Availability | Single AZ | Cost-effective for learning stage |
| API versioning | None for now | Owner controls both client and server |
| Prediction submission | One request per group (no batch endpoint) | Simple API; UI handles multi-group UX client-side |

---

## Full PostgreSQL Schema

```sql
-- Accounts
users (id UUID PK, username TEXT UNIQUE, email TEXT UNIQUE, password_hash TEXT, created_at TIMESTAMPTZ)

-- Groups
groups (id UUID PK, name TEXT, invite_code TEXT UNIQUE, created_by → users, created_at TIMESTAMPTZ)
group_members (group_id → groups, user_id → users, joined_at TIMESTAMPTZ)  PK: (group_id, user_id)

-- VCT data (written by Ingestion Worker)
tournaments (id UUID PK, name TEXT, region TEXT, starts_at TIMESTAMPTZ, ends_at TIMESTAMPTZ, status TEXT)
teams (id UUID PK, name TEXT, short_name TEXT, region TEXT)
matches (id UUID PK, tournament_id → tournaments, team_a_id → teams, team_b_id → teams,
         format TEXT, scheduled_at TIMESTAMPTZ, status TEXT, score_a INT, score_b INT,
         external_id TEXT UNIQUE)

-- Predictions (written by App Service)
predictions (id UUID PK, user_id → users, match_id → matches, group_id → groups,
             score_a INT, score_b INT, created_at TIMESTAMPTZ)
             UNIQUE (user_id, match_id, group_id)

-- Scoring (written by Scoring Worker)
points_entries (id UUID PK, prediction_id → predictions UNIQUE, points INT, is_final BOOL, updated_at TIMESTAMPTZ)
leaderboard_entries (user_id → users, group_id → groups, tournament_id → tournaments,
                     total_points INT, updated_at TIMESTAMPTZ)
                     PK: (user_id, group_id, tournament_id)
```

---

## Kafka Events

**Topic:** `match-scoring-events`
**Partition key:** `match_id`

```json
// map.completed
{
  "event_type": "map.completed",
  "event_id": "uuid",
  "published_at": "ISO8601",
  "match_id": "uuid",
  "tournament_id": "uuid",
  "team_a_id": "uuid",
  "team_b_id": "uuid",
  "score_a": 1,
  "score_b": 0,
  "format": "BO3",
  "status": "live"
}

// match.completed — same fields, status = "completed"
```

---

## API Endpoints (App Service)

```
POST /auth/register        POST /auth/login
POST /auth/refresh         POST /auth/logout

GET  /users/me

POST /groups               GET  /groups/:id
POST /groups/join          GET  /groups/:id/members
GET  /groups/:id/predictions?match_id=    (hidden until match is live)
GET  /groups/:id/leaderboard?tournament_id=

GET  /tournaments          GET  /tournaments/:id
GET  /tournaments/:id/matches
GET  /matches/:id

POST /predictions
GET  /predictions/me?group_id=
```

---

## Key Constraints (Non-Negotiables)

- Leaderboard must reflect live match state — updates after every map completion
- No manual admin intervention in the scoring pipeline
- Groups are fully isolated — predictions in Group A are independent from Group B
- Match data from external API only — no manual entry
- Internal services never exposed to the public internet
- Kafka offset committed only after all DB writes succeed (at-least-once + idempotency)

---

## Out of Scope (Explicitly Decided)

- Round-level predictions (only map scores matter)
- Public groups or group discovery
- Per-map score predictions (e.g. 13-5 on Map 1)
- Notifications / alerts
- Social features (comments, reactions)
- Mobile app
- Batch prediction endpoint (one POST per group)

---

## Docs Index

| File | Contents |
|---|---|
| `docs/00-requirements.md` | Formal FR/NFR requirements |
| `docs/01-core-entities-and-flows.md` | Entity definitions, scoring rules, user flows |
| `docs/02-data-model.md` | Full PostgreSQL schema with per-table reasoning |
| `docs/03-microservices.md` | 4-service breakdown, ownership table, architecture diagram |
| `docs/04-scoring-logic.md` | Point values, algorithm, truth table, scoring pipeline |
| `docs/05-kafka-event-design.md` | Topics, event schemas, partitioning, idempotency |
| `docs/06-external-api-integration.md` | Data source abstraction, polling jobs, error handling |
| `docs/07-aws-infrastructure.md` | ECS, RDS, MSK, VPC layout, security groups, IAM |
| `docs/08-api-design.md` | Full endpoint list, validation rules, visibility rules |
| `docs/09-build-plan.md` | 8-phase, 81-task build plan with testing per phase |
| `docs/PROJECT_CONTEXT.md` | This file |
