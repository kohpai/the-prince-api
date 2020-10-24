CREATE ROLE nologin;

CREATE ROLE authuser;

GRANT nologin TO postgraphile;
GRANT authuser TO postgraphile;

GRANT ALL ON DATABASE postgraphile TO postgraphile;

-- after schema creation and before function creation
ALTER DEFAULT privileges REVOKE EXECUTE ON functions FROM public;

GRANT usage ON SCHEMA public TO nologin, authuser;
GRANT usage ON SCHEMA graphile_worker TO postgraphile;

ALTER FUNCTION graphile_worker.add_job (text, json, text, timestamp with time zone, integer, text, integer, text[]) SECURITY DEFINER;

CREATE EXTENSION IF NOT EXISTS moddatetime;

CREATE TABLE public.customer
(
	id         text PRIMARY KEY,
	balance    money       NOT NULL DEFAULT 0,
	updated_at timestamptz NOT NULL DEFAULT now(),
	created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER mdt_customer
    BEFORE UPDATE
    ON public.customer
    FOR EACH ROW
EXECUTE PROCEDURE moddatetime(updated_at);

ALTER TABLE public.customer
    ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON TABLE public.customer TO authuser;
CREATE POLICY owner_only ON public.customer TO authuser
    USING (id = current_setting('jwt.claims.firebase_uid', TRUE));
COMMENT ON TABLE public.customer IS E'@omit create,update,delete';

CREATE TYPE public.color_mode_t AS enum (
	'COLOR',
	'BLACK'
	);

COMMENT ON TYPE public.color_mode_t IS E'@name color_mode';

CREATE TYPE public.job_status_t AS enum (
	'PLACED',
	'EXECUTED',
	'FAILED'
	);

COMMENT ON TYPE public.job_status_t IS E'@name job_status';

CREATE TABLE public.print_job
(
	id          serial PRIMARY KEY,
	customer_id text         NOT NULL REFERENCES public.customer ON DELETE CASCADE,
	filename    text         NOT NULL,
	color_mode  color_mode_t NOT NULL,
	page_range  text,
	num_pages   smallint     NOT NULL,
	num_copies  smallint     NOT NULL,
	price       money        NOT NULL,
	status      job_status_t NOT NULL DEFAULT 'PLACED',
	updated_at  timestamptz  NOT NULL DEFAULT now(),
	created_at  timestamptz  NOT NULL DEFAULT now()
);

CREATE TRIGGER mdt_print_job
    BEFORE UPDATE
    ON public.print_job
    FOR EACH ROW
EXECUTE PROCEDURE moddatetime(updated_at);

ALTER TABLE public.print_job
    ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON TABLE public.print_job TO authuser;
CREATE POLICY owner_only ON public.print_job TO authuser
    USING (customer_id = current_setting('jwt.claims.firebase_uid', TRUE));
COMMENT ON TABLE public.print_job IS E'@omit create,update,delete';


CREATE TYPE print_config_t AS
(
	color_mode color_mode_t,
	page_range text,
	num_pages  smallint,
	num_copies smallint
);

COMMENT ON TYPE public.print_config_t IS E'@name print_config';
