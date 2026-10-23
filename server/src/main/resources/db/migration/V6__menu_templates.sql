SET LOCAL lock_timeout = '5s';

ALTER TABLE chain ADD COLUMN template_code TEXT UNIQUE CHECK (template_code ~ '^[a-z][a-z0-9-]{0,63}$');
ALTER TABLE venue ADD COLUMN template_id BIGINT REFERENCES chain (id);

CREATE INDEX venue_template_idx ON venue (template_id) WHERE template_id IS NOT NULL;
