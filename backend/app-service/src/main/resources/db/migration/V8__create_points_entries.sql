CREATE TABLE points_entries (
    id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    prediction_id UUID        NOT NULL REFERENCES predictions(id) UNIQUE,
    points        INT         NOT NULL DEFAULT 0,
    is_final      BOOL        NOT NULL DEFAULT false,
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
