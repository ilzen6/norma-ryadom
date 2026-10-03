SET LOCAL lock_timeout = '5s';

ALTER TABLE venue ADD COLUMN confirmed_on DATE;
ALTER TABLE venue ADD COLUMN under_review BOOLEAN NOT NULL DEFAULT FALSE;

CREATE TABLE venue_report (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    venue_id      BIGINT      NOT NULL REFERENCES venue (id),
    reason        TEXT        NOT NULL CHECK (reason IN ('closed', 'moved', 'not_found')),
    reporter_hash TEXT        NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    resolved_at   TIMESTAMPTZ
);

CREATE UNIQUE INDEX venue_report_open_reporter_uq
    ON venue_report (venue_id, reporter_hash)
    WHERE resolved_at IS NULL;

CREATE INDEX venue_report_open_idx ON venue_report (venue_id) WHERE resolved_at IS NULL;

CREATE INDEX venue_under_review_idx ON venue (id) WHERE under_review;
