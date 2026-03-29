CREATE TABLE predictions (
    id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID        NOT NULL REFERENCES users(id),
    match_id   UUID        NOT NULL REFERENCES matches(id),
    group_id   UUID        NOT NULL REFERENCES groups(id),
    score_a    INT         NOT NULL,
    score_b    INT         NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, match_id, group_id)
);
