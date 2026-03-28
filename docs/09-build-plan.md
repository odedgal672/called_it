# Build Plan

> Status: approved
> Last updated: 2026-03-28

Legend: [ ] not started | [~] in progress | [x] done

---

## Phase 0: Project Setup

- [ ] 0.1 — Initialize Maven monorepo with parent `pom.xml`
- [ ] 0.2 — Create 5 Maven modules: `shared`, `api-gateway`, `app-service`, `ingestion-worker`, `scoring-worker`
- [ ] 0.3 — Add `docker-compose.yml` for local dev (PostgreSQL + Kafka + Zookeeper)
- [ ] 0.4 — Configure Flyway (database migration tool) in `app-service`
- [ ] 0.5 — Write all database migrations (one file per table, in order)

---

## Phase 1: Shared Module

- [ ] 1.1 — Define Kafka event classes: `MapCompletedEvent`, `MatchCompletedEvent`
- [ ] 1.2 — Define shared enums: `MatchStatus`, `MatchFormat`

---

## Phase 2: App Service

### Setup
- [ ] 2.1 — Bootstrap Spring Boot app (Spring Web, Spring Data JPA, Spring Security, PostgreSQL driver, Flyway)
- [ ] 2.2 — Configure database connection (local + env-variable-based for prod)

### Auth
- [ ] 2.3 — Implement `POST /auth/register`
- [ ] 2.4 — Implement `POST /auth/login`
- [ ] 2.5 — Implement `POST /auth/refresh`
- [ ] 2.6 — Implement `POST /auth/logout`
- [ ] 2.7 — Add JWT validation filter (reads `X-User-Id` from gateway in prod; validates JWT directly in local dev)

### Groups
- [ ] 2.8 — Implement `POST /groups`
- [ ] 2.9 — Implement `POST /groups/join`
- [ ] 2.10 — Implement `GET /groups/:id`
- [ ] 2.11 — Implement `GET /groups/:id/members`

### Tournaments & Matches
- [ ] 2.12 — Implement `GET /tournaments` and `GET /tournaments/:id`
- [ ] 2.13 — Implement `GET /tournaments/:id/matches` and `GET /matches/:id`

### Predictions
- [ ] 2.14 — Implement `POST /predictions` (with all validations)
- [ ] 2.15 — Implement `GET /predictions/me?group_id=`
- [ ] 2.16 — Implement `GET /groups/:id/predictions?match_id=` (with visibility rule)

### Leaderboard
- [ ] 2.17 — Implement `GET /groups/:id/leaderboard?tournament_id=`

### Tests
- [ ] 2.18 — Add Testcontainers dependency (spins up real PostgreSQL for integration tests)
- [ ] 2.19 — Unit tests: prediction validation rules (invalid score format, match not upcoming, user not in group)
- [ ] 2.20 — Unit tests: invite code generation (unique, correct format)
- [ ] 2.21 — Integration tests: auth flow (register → login → refresh → logout)
- [ ] 2.22 — Integration tests: group flow (create → join → get members)
- [ ] 2.23 — Integration tests: prediction submission (happy path + each rejection case)
- [ ] 2.24 — Integration tests: prediction visibility rule (hidden when upcoming, visible when live/completed)
- [ ] 2.25 — Integration tests: leaderboard ordering (correct ranking, tied users share rank)

---

## Phase 3: API Gateway

### Setup & Implementation
- [ ] 3.1 — Bootstrap Spring Cloud Gateway
- [ ] 3.2 — Add JWT validation filter
- [ ] 3.3 — Configure routes (forward to App Service with `X-User-Id` header)
- [ ] 3.4 — Whitelist public routes (`/auth/*`)

### Tests
- [ ] 3.5 — Unit tests: JWT filter rejects missing/invalid/expired tokens
- [ ] 3.6 — Unit tests: `X-User-Id` correctly extracted and attached on valid JWT
- [ ] 3.7 — Unit tests: `/auth/*` routes bypass JWT validation

---

## Phase 4: Ingestion Worker

### Setup & Implementation
- [ ] 4.1 — Bootstrap Spring Boot app (Spring Scheduler, Spring Kafka, Spring Data JPA)
- [ ] 4.2 — Define `ExternalMatchDataProvider` interface
- [ ] 4.3 — Implement `VlrGgProvider` (HTTP client, maps response to internal models)
- [ ] 4.4 — Implement Job 1: schedule sync (upsert tournaments, teams, matches every 10 min)
- [ ] 4.5 — Implement Job 2: live score sync (poll every 15s ± jitter when matches are live)
- [ ] 4.6 — Implement change detection (compare API score vs DB score)
- [ ] 4.7 — Implement Kafka producer (publish `MapCompletedEvent` / `MatchCompletedEvent`)
- [ ] 4.8 — Add retry with exponential backoff on API failures

### Tests
- [ ] 4.9 — Unit tests: `VlrGgProvider` response mapping (mock HTTP call, assert correct internal models)
- [ ] 4.10 — Unit tests: change detection (score unchanged → no event, score changed → correct event type)
- [ ] 4.11 — Unit tests: correct event type published per scenario (map completed vs match completed)
- [ ] 4.12 — Unit tests: Job 2 skips API call when no live matches exist

---

## Phase 5: Scoring Worker

### Setup & Implementation
- [ ] 5.1 — Bootstrap Spring Boot app (Spring Kafka, Spring Data JPA)
- [ ] 5.2 — Implement Kafka consumer for `match-scoring-events` topic
- [ ] 5.3 — Implement `calculatePoints(match, prediction)` algorithm
- [ ] 5.4 — Implement `points_entries` update logic (delta calculation, `is_final` flag)
- [ ] 5.5 — Implement `leaderboard_entries` update logic (apply delta per group)
- [ ] 5.6 — Add idempotency check

### Tests
- [ ] 5.7 — Unit tests: `calculatePoints` for every row in the truth table (correct winner live, tied, wrong winner, exact score, winner only on completion)
- [ ] 5.8 — Unit tests: delta calculation (points increase, decrease, no change)
- [ ] 5.9 — Unit tests: `is_final` flips on `match.completed`, not on `map.completed`
- [ ] 5.10 — Unit tests: idempotency (processing same event twice produces same result, no double update)
- [ ] 5.11 — Integration tests: full scoring pipeline (consume event → assert `points_entries` and `leaderboard_entries` updated correctly)

---

## Phase 6: Local Integration Test

*Full end-to-end smoke test — system should already be trusted from prior tests.*

- [ ] 6.1 — Run all 4 services locally via Docker Compose
- [ ] 6.2 — Register user, create group, submit predictions via API
- [ ] 6.3 — Simulate map completion (mock API or update DB directly)
- [ ] 6.4 — Verify: Kafka event published → Scoring Worker consumed → points updated → leaderboard updated

---

## Phase 7: AWS Infrastructure

- [ ] 7.1 — Create VPC, public subnet, private subnet, security groups
- [ ] 7.2 — Create NAT Gateway
- [ ] 7.3 — Provision RDS PostgreSQL instance
- [ ] 7.4 — Provision MSK (Kafka) cluster
- [ ] 7.5 — Create ECR repositories (one per service)
- [ ] 7.6 — Write Dockerfiles for all 4 services
- [ ] 7.7 — Create ECS task definitions (one per service)
- [ ] 7.8 — Create ECS services (App Service, API Gateway, Scoring Worker)
- [ ] 7.9 — Create ECS scheduled task (Ingestion Worker)
- [ ] 7.10 — Set up Application Load Balancer
- [ ] 7.11 — Store secrets in AWS Secrets Manager (DB credentials, JWT secret)
- [ ] 7.12 — Configure IAM roles per service (least privilege)

---

## Phase 8: CI/CD

- [ ] 8.1 — Set up GitHub Actions workflow: build + test on every push
- [ ] 8.2 — On merge to `main`: build Docker images, push to ECR
- [ ] 8.3 — On merge to `main`: trigger ECS rolling deployment

---

## Summary

| Phase | Tasks | Description |
|---|---|---|
| 0 | 5 | Project setup |
| 1 | 2 | Shared module |
| 2 | 25 | App Service (implementation + tests) |
| 3 | 7 | API Gateway (implementation + tests) |
| 4 | 12 | Ingestion Worker (implementation + tests) |
| 5 | 11 | Scoring Worker (implementation + tests) |
| 6 | 4 | Local integration test |
| 7 | 12 | AWS infrastructure |
| 8 | 3 | CI/CD |
| **Total** | **81** | |
