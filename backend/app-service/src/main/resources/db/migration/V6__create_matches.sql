CREATE TABLE matches (
    id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id UUID        NOT NULL REFERENCES tournaments(id),
    team_a_id     UUID        NOT NULL REFERENCES teams(id),
    team_b_id     UUID        NOT NULL REFERENCES teams(id),
    format        TEXT        NOT NULL,
    scheduled_at  TIMESTAMPTZ NOT NULL,
    status        TEXT        NOT NULL DEFAULT 'upcoming',
    score_a       INT         NOT NULL DEFAULT 0,
    score_b       INT         NOT NULL DEFAULT 0,
    external_id   TEXT        UNIQUE
);
