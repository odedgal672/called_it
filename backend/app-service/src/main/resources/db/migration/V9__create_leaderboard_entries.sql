CREATE TABLE leaderboard_entries (
    user_id       UUID        NOT NULL REFERENCES users(id),
    group_id      UUID        NOT NULL REFERENCES groups(id),
    tournament_id UUID        NOT NULL REFERENCES tournaments(id),
    total_points  INT         NOT NULL DEFAULT 0,
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, group_id, tournament_id)
);
