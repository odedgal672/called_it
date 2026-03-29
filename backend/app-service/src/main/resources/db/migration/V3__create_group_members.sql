CREATE TABLE group_members (
    group_id  UUID        NOT NULL REFERENCES groups(id),
    user_id   UUID        NOT NULL REFERENCES users(id),
    joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (group_id, user_id)
);
