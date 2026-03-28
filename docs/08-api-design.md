# API Design

> Status: decided
> Topic order: 8 of N

---

## Overview

All endpoints are served by the **App Service** behind the **API Gateway**. The API Gateway validates the JWT and attaches `X-User-Id` to every forwarded request. All endpoints below require authentication unless marked `[public]`.

No URL versioning for now. Can be added (`/api/v1/`) when the API is opened to third parties.

---

## Auth

```
POST /auth/register
  body:     { username, email, password }
  response: { user_id, username }
  auth:     [public]

POST /auth/login
  body:     { email, password }
  response: { access_token, refresh_token, expires_in }
  auth:     [public]

POST /auth/refresh
  body:     { refresh_token }
  response: { access_token, expires_in }
  auth:     [public]

POST /auth/logout
  body:     { refresh_token }
  response: 204 No Content
  note:     invalidates the refresh token
```

---

## Users

```
GET /users/me
  response: { user_id, username, email, created_at }
```

---

## Groups

```
POST /groups
  body:     { name }
  response: { group_id, name, invite_code }
  note:     creates group; requesting user becomes first member

GET /groups/:id
  response: { group_id, name, invite_code, member_count, created_at }

POST /groups/join
  body:     { invite_code }
  response: { group_id, name }
  note:     adds requesting user as a member

GET /groups/:id/members
  response: [{ user_id, username, joined_at }]
```

---

## Tournaments & Matches

```
GET /tournaments
  response: [{ tournament_id, name, region, starts_at, ends_at, status }]
  note:     returns active and upcoming tournaments only

GET /tournaments/:id
  response: { tournament_id, name, region, starts_at, ends_at, status }

GET /tournaments/:id/matches
  response: [{ match_id, team_a, team_b, format, scheduled_at,
               status, score_a, score_b }]
  note:     team fields include { team_id, name, short_name }

GET /matches/:id
  response: { match_id, tournament_id, team_a, team_b, format,
              scheduled_at, status, score_a, score_b }
```

---

## Predictions

```
POST /predictions
  body:     { match_id, group_id, score_a, score_b }
  response: { prediction_id, match_id, group_id, score_a, score_b, created_at }
  note:     rejected if match status != 'upcoming'
            rejected if user is not a member of group_id
            rejected if score is invalid for match format
            (e.g. 3-0 not valid for BO3)

GET /predictions/me?group_id=
  response: [{ prediction_id, match_id, group_id, score_a, score_b,
               points, is_final, created_at }]
  note:     returns all of the requesting user's predictions in a group
            includes current points and finalization status

GET /groups/:id/predictions?match_id=
  response: [{ user_id, username, score_a, score_b, points, is_final }]
  note:     visibility rule — only returns data if match status is 'live'
            or 'completed'. Returns 403 if match is still 'upcoming'.
```

---

## Leaderboard

```
GET /groups/:id/leaderboard?tournament_id=
  response: [{ rank, user_id, username, total_points }]
  note:     ordered by total_points descending
            rank is computed server-side (1, 2, 3...)
            tied users share the same rank
```

---

## Validation Rules (App Service responsibilities)

| Endpoint | Validations |
|---|---|
| `POST /predictions` | Match must be `upcoming`; user must be member of group; score must be valid for format (BO3: 2-0, 2-1; BO5: 3-0, 3-1, 3-2); one prediction per user+match+group |
| `POST /groups/join` | Invite code must exist; user not already a member |
| `GET /groups/:id/*` | Requesting user must be a member of the group |
| `GET /groups/:id/predictions` | Match must be `live` or `completed` |

---

## Key Design Decisions

| Decision | Choice | Reasoning |
|---|---|---|
| Versioning | None for now | Owner controls both frontend and backend; add `/api/v1/` when opening to third parties |
| Prediction submission | One request per group | Keeps API simple; UI handles multi-group UX by firing parallel requests |
| Prediction visibility | Hidden until match is live | Prevents copying; 403 returned if match is still upcoming |
| Leaderboard scope | Per group + per tournament | Consistent with data model; `tournament_id` required query param |
| Rank computation | Server-side | Client receives ready-to-render ranks; tied users share rank |
