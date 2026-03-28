# External API Integration

> Status: decided
> Topic order: 6 of N

---

## Data Source

**VLR.gg via unofficial wrapper** — used as the initial implementation behind an abstraction layer.

The Ingestion Worker never calls VLR.gg directly. It calls an `ExternalMatchDataProvider` interface. This means the underlying data source can be swapped (e.g. to Riot Games official Esports API) without changing any other part of the system.

```
Ingestion Worker
  └── ExternalMatchDataProvider (interface)
        └── VlrGgProvider (implementation)   ← start here
        └── RiotEsportsProvider (future)
```

---

## Polling Jobs

The Ingestion Worker runs two independent scheduled jobs:

### Job 1 — Schedule Sync
**Interval:** every 10 minutes

**Purpose:** Keep tournament, team, and match schedule data fresh. Handles initial bootstrapping — first run seeds everything, subsequent runs upsert changes.

**Logic:**
1. Fetch upcoming and active VCT matches from external API
2. For each result:
   - Upsert `tournaments` (insert if new, update if changed)
   - Upsert `teams` (insert if new, update if changed)
   - Upsert `matches` (insert if new, update schedule/status if changed)
3. Uses `external_id` on matches to correlate API data with DB rows

**Runs when:** always, as long as there is an active or upcoming tournament in the DB.

---

### Job 2 — Live Score Sync
**Interval:** every 15 seconds ± 3 seconds random jitter

**Purpose:** Detect map completions and match endings during live matches. Triggers the scoring pipeline via Kafka.

**Logic:**
1. Query DB: `SELECT * FROM matches WHERE status = 'live'`
2. If no live matches → skip (do not call external API)
3. For each live match: fetch current score from external API
4. Compare API score against DB `score_a` / `score_b`
5. If score changed:
   - Update `matches` table (`score_a`, `score_b`)
   - Determine event type:
     - Team reached win threshold (2 in BO3, 3 in BO5) → update `status = 'completed'`, publish `match.completed`
     - Score changed but match not over → publish `map.completed`
6. If status changed to `live` (detected via Job 1 or score fetch): update `matches.status = 'live'`

**Rate limiting mitigations:**
- `User-Agent: CalledIt.gg/1.0` header on all requests
- Job 2 skips entirely when no matches are live (zero overnight requests)
- ±3 second jitter prevents metronomic request pattern

---

## Change Detection

The Ingestion Worker detects changes by comparing the API response against the current DB state:

| Field compared | Triggers |
|---|---|
| `score_a` or `score_b` changed | Publish `map.completed` or `match.completed` |
| `status` changed to `live` | Update `matches.status`, Job 2 begins polling this match |
| `status` changed to `completed` | Publish `match.completed`, Job 2 stops polling this match |
| New match not in DB | Insert via Job 1 upsert |

---

## Error Handling

**Strategy:** retry with exponential backoff; catch up on recovery.

If the external API returns an error or times out:
- Retry: 15s → 30s → 60s → 120s
- After 5 consecutive failures: log error, continue retrying at 120s interval
- When API recovers: next successful poll detects the latest score, publishes all relevant events
- Leaderboard is frozen during outage but **correct on recovery** — no data is permanently lost

This works safely because the scoring pipeline is always driven by the **latest known state**, not a sequence of diffs. Missing intermediate map scores is acceptable — the final state will always be correct.

---

## Key Design Decisions

| Decision | Choice | Reasoning |
|---|---|---|
| Data source | VLR.gg (unofficial) via abstraction | Unblocks development immediately; Riot API requires approval |
| Provider abstraction | `ExternalMatchDataProvider` interface | Swap data sources without touching ingestion logic |
| Bootstrapping | Job 1 upserts on every run | No manual seeding needed; first run seeds, subsequent runs refresh |
| Live polling interval | 15s ± 3s jitter | Near real-time feel; low enough request rate to avoid blocks |
| Schedule polling interval | Every 10 minutes | Infrequent changes; no need for high frequency |
| API downtime | Retry with backoff, catch up on recovery | Correct eventual state guaranteed; leaderboard freezes but self-heals |
| Overnight behavior | Job 2 skips when no live matches | Zero unnecessary API calls outside tournament hours |
