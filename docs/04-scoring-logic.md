# Scoring Logic

> Status: decided
> Topic order: 4 of N

---

## Point Values

| Outcome | Points |
|---|---|
| Correct winner (predicted winner is currently leading) | 1 pt |
| Exact score bonus (match completed, score matches exactly) | +2 pts |
| **Exact score total** | **3 pts** |
| Wrong winner or tied match | 0 pts |

Points are **additive** — exact score gives winner points + bonus on top.
The exact score bonus is only awarded when the match is fully completed.

---

## Algorithm

Runs in the Scoring Worker after every `map.completed` and `match.completed` event.

```
function calculate_points(match, prediction) -> int:

  // Tied match → 0 points
  if match.score_a == match.score_b:
    return 0

  // Determine who is currently leading
  current_leader = 'a' if match.score_a > match.score_b else 'b'

  // Determine who the user predicted to win
  predicted_winner = 'a' if prediction.score_a > prediction.score_b else 'b'

  // Wrong predicted winner → 0 points
  if current_leader != predicted_winner:
    return 0

  // Correct winner → 1 point minimum
  points = 1

  // Exact score bonus: only possible when match is completed
  if match.status == 'completed':
    if prediction.score_a == match.score_a and prediction.score_b == match.score_b:
      points += 2

  return points
```

---

## Truth Table

| Prediction | Match state | Points | Reason |
|---|---|---|---|
| Team A 2-0 | Live, score 1-0 (A leading) | 1 | Correct winner, match ongoing |
| Team A 2-0 | Live, score 1-1 (tied) | 0 | Tied — no winner yet |
| Team A 2-0 | Live, score 0-1 (B leading) | 0 | Wrong winner |
| Team A 2-0 | Completed, final 2-0 | 3 | Exact score |
| Team A 2-1 | Completed, final 2-0 | 1 | Correct winner, wrong score |
| Team B 2-1 | Completed, final 2-0 | 0 | Wrong winner |

---

## Scoring Pipeline (Scoring Worker)

Triggered by Kafka events: `map.completed`, `match.completed`

1. Receive event containing `match_id` and current match state (`score_a`, `score_b`, `status`)
2. Load all `predictions` for that `match_id`
3. For each prediction:
   - Run `calculate_points(match, prediction)`
   - Compute delta: `new_points - current points_entry.points`
   - Update `points_entries` row (set `points`, flip `is_final = true` if `match.status == completed`)
   - For each group the prediction belongs to:
     - Apply delta to `leaderboard_entries` row for `(user_id, group_id, tournament_id)`
4. Done — leaderboard is now up to date

---

## Key Design Decisions

| Decision | Choice | Reasoning |
|---|---|---|
| Point values | 1pt winner + 2pt exact bonus | Exact score is 3x winner-only; precision is the dominant skill |
| Structure | Additive | Exact score builds on winner points — always strictly better |
| Exact score timing | Completed matches only | Can't award exact score on an intermediate map score |
| Tied match | 0 points | No winner to reward yet |
| Scoring trigger | Per Kafka event | Decoupled from ingestion; retryable if scoring worker falls behind |
