# Data Model

> Status: decided
> Topic order: 2 of N

---

## Database

**PostgreSQL** — relational, strong consistency, foreign keys, joins. Hosted on AWS (RDS or Aurora Postgres).

---

## Schema

### `users`
```sql
users
  id            UUID         PRIMARY KEY  DEFAULT gen_random_uuid()
  username      TEXT         NOT NULL UNIQUE
  email         TEXT         NOT NULL UNIQUE
  password_hash TEXT         NOT NULL
  created_at    TIMESTAMPTZ  NOT NULL DEFAULT now()
```

### `groups`
```sql
groups
  id          UUID         PRIMARY KEY  DEFAULT gen_random_uuid()
  name        TEXT         NOT NULL
  invite_code TEXT         NOT NULL UNIQUE  -- short human-readable code, e.g. "WOLF-42"
  created_by  UUID         NOT NULL REFERENCES users(id)
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
```

### `group_members`
```sql
group_members
  group_id   UUID         NOT NULL REFERENCES groups(id)
  user_id    UUID         NOT NULL REFERENCES users(id)
  joined_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
  PRIMARY KEY (group_id, user_id)
```
Composite PK prevents a user joining the same group twice.

### `tournaments`
```sql
tournaments
  id         UUID         PRIMARY KEY  DEFAULT gen_random_uuid()
  name       TEXT         NOT NULL  -- e.g. "VCT Masters Bangkok 2025"
  region     TEXT                   -- e.g. "EMEA", "Pacific", "Americas", "Global"
  starts_at  TIMESTAMPTZ  NOT NULL
  ends_at    TIMESTAMPTZ  NOT NULL
  status     TEXT         NOT NULL DEFAULT 'upcoming'  -- upcoming | active | completed
```

### `teams`
```sql
teams
  id          UUID  PRIMARY KEY  DEFAULT gen_random_uuid()
  name        TEXT  NOT NULL     -- e.g. "Fnatic"
  short_name  TEXT  NOT NULL     -- e.g. "FNC"
  region      TEXT
```
Teams are global — the same row is referenced across all tournaments and matches.

### `matches`
```sql
matches
  id             UUID         PRIMARY KEY  DEFAULT gen_random_uuid()
  tournament_id  UUID         NOT NULL REFERENCES tournaments(id)
  team_a_id      UUID         NOT NULL REFERENCES teams(id)
  team_b_id      UUID         NOT NULL REFERENCES teams(id)
  format         TEXT         NOT NULL   -- 'BO3' | 'BO5'
  scheduled_at   TIMESTAMPTZ  NOT NULL
  status         TEXT         NOT NULL DEFAULT 'upcoming'  -- upcoming | live | completed
  score_a        INT          NOT NULL DEFAULT 0  -- maps won by team_a (updated live)
  score_b        INT          NOT NULL DEFAULT 0  -- maps won by team_b (updated live)
  external_id    TEXT         UNIQUE               -- ID from external API, used for deduplication
```
`score_a` / `score_b` update after each map completion. When `status = completed` these are the final scores.

### `predictions`
```sql
predictions
  id          UUID         PRIMARY KEY  DEFAULT gen_random_uuid()
  user_id     UUID         NOT NULL REFERENCES users(id)
  match_id    UUID         NOT NULL REFERENCES matches(id)
  group_id    UUID         NOT NULL REFERENCES groups(id)
  score_a     INT          NOT NULL  -- predicted maps for team_a
  score_b     INT          NOT NULL  -- predicted maps for team_b
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
  UNIQUE (user_id, match_id, group_id)
```
A user can make a different prediction for the same match in each group they belong to. The unique constraint enforces one prediction per user per match per group.

### `points_entries`
```sql
points_entries
  id            UUID         PRIMARY KEY  DEFAULT gen_random_uuid()
  prediction_id UUID         NOT NULL REFERENCES predictions(id) UNIQUE
  points        INT          NOT NULL DEFAULT 0
  is_final      BOOL         NOT NULL DEFAULT false
  updated_at    TIMESTAMPTZ  NOT NULL DEFAULT now()
```
One row per prediction. Updated in place after each map completion. `is_final` flips to `true` when the match ends and points lock permanently.

### `leaderboard_entries`
```sql
leaderboard_entries
  user_id        UUID         NOT NULL REFERENCES users(id)
  group_id       UUID         NOT NULL REFERENCES groups(id)
  tournament_id  UUID         NOT NULL REFERENCES tournaments(id)
  total_points   INT          NOT NULL DEFAULT 0
  updated_at     TIMESTAMPTZ  NOT NULL DEFAULT now()
  PRIMARY KEY (user_id, group_id, tournament_id)
```
Pre-aggregated standings. Updated whenever a `points_entry` changes — scoring service computes the delta and applies it here. Leaderboard reads are a simple `SELECT ... ORDER BY total_points DESC` with no joins.

---

## Entity Relationships

```
tournaments ──< matches >── teams
                  │
              predictions ──── groups
              (user + match + group)
                  │
            points_entries
            (one per prediction)

users >──< group_members >──< groups

leaderboard_entries
(user + group + tournament → total_points)
```

---

## Authentication

- API Gateway handles JWT issuance and validation
- `password_hash` stored in `users` table (bcrypt)
- On login: gateway validates credentials, issues short-lived JWT + refresh token
- Downstream microservices receive `X-User-Id` header from gateway — no re-authentication
- Internal services only accept traffic from within the VPC

## Key Design Decisions

| Decision | Choice | Reason |
|---|---|---|
| Database | PostgreSQL | Data is relational; strong consistency needed for scoring |
| Primary keys | UUID | Harder to guess; safe for public URLs and invite codes |
| Auth | Roll-your-own JWT at gateway | Microservices stay auth-free; good for learning |
| Predictions | Per user + match + **group** | Users can predict differently across groups |
| Leaderboard | Pre-aggregated table | O(1) reads; updated by scoring pipeline on each map result |
| Points storage | Stored + updated in place | Simple delta updates; `is_final` flag locks on match end |
