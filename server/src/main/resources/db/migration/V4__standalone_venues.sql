SET LOCAL lock_timeout = '5s';

CREATE UNIQUE INDEX venue_standalone_external_uq ON venue (external_id)
    WHERE chain_id IS NULL AND external_id IS NOT NULL;
