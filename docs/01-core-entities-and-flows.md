# Core Entities & User Flows

> Status: decided
> Topic order: 1 of N

---

## Entities

### User
A registered account. Can belong to multiple groups simultaneously.

### Group
A private, invite-only league. Created by a user who shares an invite code/link. Members compete against each other on a per-tournament leaderboard.

### Tournament
A named VCT event (e.g. "VCT Masters Bangkok 2025"). All matches, predictions, and leaderboards are scoped to a tournament.

### Match
A single match within a tournament between two teams.

| Field | Description |
|---|---|
| tournament | Parent tournament |
| team_a / team_b | Competing teams |
| format | BO3 or BO5 |
| scheduled_start | When the match begins (predictions lock at this time) |
| current_score | Current map score during live play (e.g. team_a: 1, team_b: 0) |
| status | `upcoming` / `live` / `completed` |

### Prediction
A user's predicted map score for a match. Submitted before match start; locked when status becomes `live`.

| Field | Description |
|---|---|
| user | Who predicted |
| match | Which match |
| predicted_score_a | Maps predicted for team A |
| predicted_score_b | Maps predicted for team B |

Valid predictions: 2-0, 2-1 (BO3) or 3-0, 3-1, 3-2 (BO5).

### PointsEntry
The current awarded points for a prediction. Recalculated after each map completion; finalized when the match ends.

| Field | Description |
|---|---|
| prediction | Which prediction this scores |
| points | Current points awarded |
| is_final | Whether the match has ended and points are locked |

### LeaderboardEntry
Aggregated points per user, per group, per tournament. Updated live as PointsEntries change.

---

## Scoring Rules

Points are recalculated after every map completion using the **current map score** as if it were the final result.

| Situation | Points |
|---|---|
| Predicted winner is currently leading | Winner points |
| Match is currently tied (e.g. 1-1 in BO3) | 0 |
| Match over, predicted winner correct, score wrong | Winner points (finalized) |
| Match over, predicted score exact | Exact score points (finalized) |
| Predicted winner lost | 0 (finalized) |

Exact point values (winner points, exact score points) are TBD — to be decided in the scoring design topic.

---

## User Flows

1. **Register / Login** → user creates an account
2. **Create group** → user gets an invite code to share with friends
3. **Join group** → user enters invite code, becomes a group member
4. **Browse matches** → user sees upcoming matches in the current tournament
5. **Submit prediction** → user enters a map score (e.g. 2-1) before match starts; locked at kickoff
6. **Map completes (live)** → external API delivers updated map score → system recalculates points for all predictions on that match → all affected leaderboards update
7. **Match ends** → final map score confirmed → points finalized and locked for all predictions
8. **View leaderboard** → user sees live standings per group, scoped to the current tournament

---

## Match Data Source

Match schedules and live results are pulled from an **external API** (e.g. VLR.gg or Riot API). No manual admin entry. The system must handle API updates gracefully — live score updates trigger the scoring pipeline automatically.
