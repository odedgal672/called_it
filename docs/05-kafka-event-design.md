# Kafka Event Design

> Status: decided
> Topic order: 5 of N

---

## Topics

| Topic | Events | Consumers | Notes |
|---|---|---|---|
| `match-scoring-events` | `map.completed`, `match.completed` | Scoring Worker | Ordering guaranteed per match via `match_id` partition key |

Events that don't affect scoring (e.g. future notifications, audit logs) go in separate topics. `match.started` does not need a Kafka event — the Ingestion Worker updates `matches.status` directly in the DB; the App Service reads from DB when validating predictions.

---

## Event Schemas

### `map.completed`
Published by Ingestion Worker after detecting a map score change from the external API.

```json
{
  "event_type": "map.completed",
  "event_id": "uuid",
  "published_at": "2025-04-10T14:32:00Z",
  "match_id": "uuid",
  "tournament_id": "uuid",
  "team_a_id": "uuid",
  "team_b_id": "uuid",
  "score_a": 1,
  "score_b": 0,
  "format": "BO3",
  "status": "live"
}
```

### `match.completed`
Published by Ingestion Worker when a match reaches its final score.

```json
{
  "event_type": "match.completed",
  "event_id": "uuid",
  "published_at": "2025-04-10T16:05:00Z",
  "match_id": "uuid",
  "tournament_id": "uuid",
  "team_a_id": "uuid",
  "team_b_id": "uuid",
  "score_a": 2,
  "score_b": 1,
  "format": "BO3",
  "status": "completed"
}
```

Both events carry the same fields — the `status` field distinguishes them, along with `event_type`. The Scoring Worker uses the same `calculate_points` algorithm for both; the difference is `match.completed` triggers `is_final = true` on all `points_entries` for that match.

---

## Partitioning

| Setting | Value |
|---|---|
| Partition key | `match_id` |
| Guarantee | All events for the same match land on the same partition → processed in order |

This ensures `map.completed` is always processed before `match.completed` for the same match. Multiple matches in parallel are handled across different partitions.

---

## Event Style

**Fat events** — full match state is included in the payload. The Scoring Worker does not need to re-query the DB for match state; it has everything needed to run `calculate_points`. It still queries the DB for predictions (to know what to score).

---

## Scoring Worker — Consumption Flow

1. Consume event from `match-scoring-events`
2. Extract `match_id`, `score_a`, `score_b`, `status` from payload
3. Query `predictions` table: `SELECT * FROM predictions WHERE match_id = ?`
4. For each prediction:
   - Run `calculate_points(event, prediction)`
   - Compute delta vs current `points_entries.points`
   - `UPDATE points_entries SET points = ?, updated_at = now() WHERE prediction_id = ?`
   - If `event_type == 'match.completed'`: also set `is_final = true`
   - `UPDATE leaderboard_entries SET total_points = total_points + delta WHERE user_id = ? AND group_id = ? AND tournament_id = ?`
5. Commit Kafka offset (only after all DB writes succeed — ensures at-least-once processing)

---

## Idempotency Note

If the Scoring Worker crashes mid-batch and restarts, it will re-process the last uncommitted event. This means the same event could be scored twice. The safe guard is to check the current `points_entries.points` before applying a delta — if the value already matches what the event would produce, skip the update. This makes the worker idempotent.

---

## Key Design Decisions

| Decision | Choice | Reasoning |
|---|---|---|
| Event payload | Fat events | Ingestion Worker is source of truth; bundling fresh data avoids extra DB query for match state |
| Topic structure | One topic for scoring events; separate topics for unrelated concerns | Groups events that need ordering together; avoids losing order guarantees |
| Partition key | `match_id` | Guarantees ordered processing per match; parallel matches handled across partitions |
| `match.started` | Not a Kafka event | Ingestion Worker writes directly to DB; no async processing needed for prediction locking |
| Offset commit | After all DB writes succeed | Ensures at-least-once delivery; combined with idempotency logic prevents double-scoring |
