CREATE TABLE teams (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name       TEXT NOT NULL,
    short_name TEXT NOT NULL,
    region     TEXT
);
