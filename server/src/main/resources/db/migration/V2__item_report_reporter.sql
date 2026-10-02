SET LOCAL lock_timeout = '5s';

ALTER TABLE item_report ADD COLUMN reporter_hash TEXT;

CREATE UNIQUE INDEX item_report_open_reporter_uq
    ON item_report (item_id, reporter_hash)
    WHERE resolved_at IS NULL AND reporter_hash IS NOT NULL;
