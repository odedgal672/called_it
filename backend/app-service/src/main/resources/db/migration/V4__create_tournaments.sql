CREATE TABLE tournaments (
    id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    name       TEXT        NOT NULL,
    region     TEXT,
    starts_at  TIMESTAMPTZ NOT NULL,
    ends_at    TIMESTAMPTZ NOT NULL,
    status     TEXT        NOT NULL DEFAULT 'upcoming'
);
