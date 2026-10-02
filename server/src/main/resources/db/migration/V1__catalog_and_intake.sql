SET LOCAL lock_timeout = '5s';

CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE chain (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name         TEXT        NOT NULL UNIQUE CHECK (length(btrim(name)) > 0),
    country      CHAR(2)     NOT NULL DEFAULT 'RU',
    currency     CHAR(3)     NOT NULL DEFAULT 'RUB',
    source_url   TEXT,
    menu_version BIGINT      NOT NULL DEFAULT 0
);

CREATE TABLE venue (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    chain_id     BIGINT REFERENCES chain (id),
    name         TEXT                   NOT NULL CHECK (length(btrim(name)) > 0),
    address      TEXT                   NOT NULL,
    location     GEOGRAPHY(POINT, 4326) NOT NULL,
    external_id  TEXT,
    is_active    BOOLEAN                NOT NULL DEFAULT TRUE,
    menu_version BIGINT                 NOT NULL DEFAULT 0
);

CREATE INDEX venue_location_gix ON venue USING GIST (location);
CREATE INDEX venue_chain_idx ON venue (chain_id);
CREATE UNIQUE INDEX venue_chain_external_uq ON venue (chain_id, external_id) WHERE external_id IS NOT NULL;

CREATE TABLE menu_item (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    chain_id     BIGINT REFERENCES chain (id),
    venue_id     BIGINT REFERENCES venue (id),
    name         TEXT          NOT NULL CHECK (length(btrim(name)) > 0),
    category     TEXT          NOT NULL CHECK (category IN ('main', 'side', 'salad', 'drink', 'dessert', 'sauce')),
    portion_g    NUMERIC(6, 1) CHECK (portion_g > 0),
    kcal         NUMERIC(6, 1) NOT NULL CHECK (kcal >= 0),
    protein_g    NUMERIC(5, 1) NOT NULL CHECK (protein_g >= 0),
    fat_g        NUMERIC(5, 1) NOT NULL CHECK (fat_g >= 0),
    carbs_g      NUMERIC(5, 1) NOT NULL CHECK (carbs_g >= 0),
    price_minor  INT CHECK (price_minor >= 0),
    tags         TEXT[]        NOT NULL DEFAULT '{}',
    source_kind  CHAR(1)       NOT NULL CHECK (source_kind IN ('A', 'B', 'C')),
    source_url   TEXT,
    verified_at  TIMESTAMPTZ,
    kcal_low     NUMERIC(6, 1),
    kcal_high    NUMERIC(6, 1),
    is_available BOOLEAN       NOT NULL DEFAULT TRUE,
    under_review BOOLEAN       NOT NULL DEFAULT FALSE,
    CHECK ((chain_id IS NULL) <> (venue_id IS NULL)),
    CHECK ((source_kind = 'C') = (kcal_low IS NOT NULL AND kcal_high IS NOT NULL)),
    CHECK (kcal_low IS NULL OR kcal_low <= kcal_high)
);

CREATE INDEX menu_item_chain_idx ON menu_item (chain_id) WHERE is_available;
CREATE INDEX menu_item_venue_idx ON menu_item (venue_id) WHERE is_available;
CREATE INDEX menu_item_tags_gin ON menu_item USING GIN (tags);
CREATE UNIQUE INDEX menu_item_chain_name_uq ON menu_item (chain_id, name) WHERE chain_id IS NOT NULL;
CREATE UNIQUE INDEX menu_item_venue_name_uq ON menu_item (venue_id, name) WHERE venue_id IS NOT NULL;

CREATE TABLE menu_submission (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    venue_id     BIGINT      NOT NULL REFERENCES venue (id),
    photo_key    TEXT        NOT NULL UNIQUE,
    content_type TEXT        NOT NULL,
    ocr_text     TEXT,
    status       TEXT        NOT NULL DEFAULT 'NEW'
        CHECK (status IN ('NEW', 'OCR_DONE', 'OCR_FAILED', 'APPROVED', 'REJECTED')),
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    moderated_at TIMESTAMPTZ
);

CREATE INDEX menu_submission_venue_idx ON menu_submission (venue_id);
CREATE INDEX menu_submission_status_idx ON menu_submission (status, created_at);

CREATE TABLE item_report (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    item_id     BIGINT      NOT NULL REFERENCES menu_item (id),
    reason      TEXT        NOT NULL CHECK (length(btrim(reason)) > 0),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    resolved_at TIMESTAMPTZ
);

CREATE INDEX item_report_item_idx ON item_report (item_id);
CREATE INDEX item_report_open_idx ON item_report (item_id) WHERE resolved_at IS NULL;
