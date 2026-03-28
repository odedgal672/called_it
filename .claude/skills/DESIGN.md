       1 # CLAUDE.md — CalledIt.gg
       2
       3 ## On Every Session Start
       4
       5 1. Read `docs/PROJECT_CONTEXT.md` — it is the single source of truth for this project.
       6 2. Ask the owner what they want to work on. Do not assume.
       7
       8 ---
       9
      10 ## What This Project Is
      11
      12 CalledIt.gg is a VCT predictions league web app. Full architecture design is complete. The project is in the **implementation phase**.
      13
      14 This is a learning project — the owner is learning AWS, PostgreSQL, microservices, and Kafka by building a real product. Do not make decisions for them. Guide, explain, and implement only what is asked.
      15
      16 ---
      17
      18 ## Tech Stack (Do Not Suggest Alternatives)
      19
      20 - **Language:** Java
      21 - **Framework:** Spring Boot
      22 - **Build tool:** Maven (monorepo with parent POM)
      23 - **Database:** PostgreSQL (AWS RDS)
      24 - **Messaging:** Apache Kafka (Amazon MSK)
      25 - **Compute:** AWS ECS Fargate
      26 - **Gateway:** Spring Cloud Gateway
      27 - **Migrations:** Flyway
      28 - **Testing:** JUnit 5 + Testcontainers
      29
      30 ---
      31
      32 ## Working Rules
      33
      34 ### Implementation tasks
      35 - Owner references tasks by number from `docs/09-build-plan.md` (e.g. "implement task 2.3")
      36 - Read the relevant docs before writing any code
      37 - Never invent architecture decisions not documented in `/docs/`
      38 - If something is unclear or undocumented, ask before implementing
      39
      40 ### Design tasks (if design topics come up)
      41 - One topic at a time
      42 - Explain options and trade-offs, then ask the owner to decide
      43 - Challenge choices that have real downsides
      44 - Document agreed decisions in `/docs/` before moving on
      45
      46 ### Always
      47 - Do not re-explain decisions already made unless the owner asks
      48 - Do not suggest technologies outside the agreed stack
      49 - Keep responses concise — the owner can read the docs for detail
      50 - Update `docs/09-build-plan.md` task status as work completes (`[ ]` → `[x]`)
      51
      52 ---
      53
      54 ## Docs Index
      55
      56 | File | Contents |
      57 |---|---|
      58 | `docs/PROJECT_CONTEXT.md` | Full project state, all decisions, schema, stack — start here |
      59 | `docs/09-build-plan.md` | 81-task build plan — track progress here |
      60 | `docs/02-data-model.md` | PostgreSQL schema |
      61 | `docs/03-microservices.md` | 4-service breakdown |
      62 | `docs/04-scoring-logic.md` | Scoring algorithm + truth table |
      63 | `docs/05-kafka-event-design.md` | Kafka topics, event schemas |
      64 | `docs/08-api-design.md` | Full REST endpoint list |