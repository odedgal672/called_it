# CalledIt.gg — Product Requirements

> This document captures formal product requirements as they are decided. Updated incrementally as design sessions progress.

---

## Product Overview

CalledIt.gg is a VCT predictions league web application. Users join private groups, predict match map scores, and compete on leaderboards scoped to VCT tournaments.

---

## Functional Requirements

### Authentication
- FR-01: Users must be able to register and log in to an account.

### Groups
- FR-02: A user can create a group. Creating a group generates a unique invite code/link.
- FR-03: A user can join a group by entering an invite code.
- FR-04: Groups are private and invite-only — no public discovery.
- FR-05: A user can belong to multiple groups simultaneously.

### Tournaments & Matches
- FR-06: Matches are organized under tournaments (e.g. "VCT Masters Bangkok 2025").
- FR-07: Each match has two teams, a format (BO3 or BO5), and a scheduled start time.
- FR-08: Match schedules and live results are sourced from an external API (e.g. VLR.gg or Riot API). No manual admin data entry.

### Predictions
- FR-09: A user can submit a map score prediction for any upcoming match (e.g. 2-1 in a BO3).
- FR-10: Valid predictions are: 2-0, 2-1 (BO3) or 3-0, 3-1, 3-2 (BO5). The winner is inferred from the score — users do not select the winner separately.
- FR-11: Predictions lock when the match starts. No changes permitted after kickoff.

### Live Scoring
- FR-12: Points are recalculated automatically after every map completion during a live match.
- FR-13: Scoring is based on the current map score as if it were the final result:
  - Predicted winner is currently leading → winner points awarded
  - Match is tied → 0 points
  - Match over, predicted winner correct, score wrong → winner points (finalized)
  - Match over, predicted score exact → exact score points (finalized)
  - Predicted winner lost → 0 points (finalized)
- FR-14: Points are finalized and locked when a match ends. No manual confirmation required.
- FR-15: There is no manual admin override for scores. The system must handle API corrections automatically by re-running the scoring pipeline.

### Leaderboards
- FR-16: Leaderboards are scoped per group and per tournament.
- FR-17: Leaderboards update in real-time as points change during live matches.

---

## Non-Functional Requirements

### Data
- NFR-01: Primary database is PostgreSQL.
- NFR-02: All primary keys are UUIDs.

### Authentication
- NFR-03: Authentication is handled at the API gateway via JWT (short-lived access token + refresh token).
- NFR-04: Downstream microservices trust the `X-User-Id` header forwarded by the gateway — no re-authentication per service.
- NFR-05: Internal services only accept traffic from within the private network (VPC).

---

## Out of Scope (for now)

- Individual map score predictions (e.g. 13-5 on Map 1) — users only predict the overall match map score
- Public groups or group discovery
- Notifications / alerts
- Social features (comments, reactions)
- Mobile app
