# CLAUDE.md — CalledIt.gg

## On Every Session Start

1. Read `docs/PROJECT_CONTEXT.md` — it is the single source of truth for this project.
2. Ask the owner what they want to work on. Do not assume.

---

## What This Project Is

CalledIt.gg is a VCT predictions league web app. Full architecture design is complete. The project is in the **implementation phase**.

This is a learning project — the owner is learning AWS, PostgreSQL, microservices, and Kafka by building a real product. Do not make decisions for them. Guide, explain, and implement only what is asked.

---

## Tech Stack (Do Not Suggest Alternatives)

- **Language:** Java
- **Framework:** Spring Boot
- **Build tool:** Maven (monorepo with parent POM)
- **Database:** PostgreSQL (AWS RDS)
- **Messaging:** Apache Kafka (Amazon MSK)
- **Compute:** AWS ECS Fargate
- **Gateway:** Spring Cloud Gateway
- **Migrations:** Flyway
- **Testing:** JUnit 5 + Testcontainers

---

## Working Rules

### Implementation tasks
- Owner references tasks by number from `docs/09-build-plan.md` (e.g. "implement task 2.3")
- Read the relevant docs before writing any code
- Never invent architecture decisions not documented in `/docs/`
- If something is unclear or undocumented, ask before implementing

### Design tasks (if design topics come up)
- One topic at a time
- Explain options and trade-offs, then ask the owner to decide
- Challenge choices that have real downsides
- Document agreed decisions in `/docs/` before moving on

### Always
- Do not re-explain decisions already made unless the owner asks
- Do not suggest technologies outside the agreed stack
- Keep responses concise — the owner can read the docs for detail
- Update `docs/09-build-plan.md` task status as work completes (`[ ]` → `[x]`)

---

## Docs Index

| File | Contents |
|---|---|
| `docs/PROJECT_CONTEXT.md` | Full project state, all decisions, schema, stack — start here |
| `docs/09-build-plan.md` | 81-task build plan — track progress here |
| `docs/02-data-model.md` | PostgreSQL schema |
| `docs/03-microservices.md` | 4-service breakdown |
| `docs/04-scoring-logic.md` | Scoring algorithm + truth table |
| `docs/05-kafka-event-design.md` | Kafka topics, event schemas |
| `docs/08-api-design.md` | Full REST endpoint list |
