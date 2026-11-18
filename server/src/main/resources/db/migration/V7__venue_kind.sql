SET LOCAL lock_timeout = '5s';

ALTER TABLE venue ADD COLUMN kind TEXT CHECK (kind ~ '^[a-z][a-z0-9-]{0,63}$');
