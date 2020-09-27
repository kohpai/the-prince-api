CREATE ROLE nologin;

CREATE ROLE authuser;

GRANT nologin TO postgraphile;

GRANT authuser TO postgraphile;

GRANT ALL ON DATABASE postgraphile TO postgraphile;

-- after schema creation and before function creation
ALTER DEFAULT privileges REVOKE EXECUTE ON functions FROM public;

GRANT usage ON SCHEMA public TO nologin, authuser;

GRANT usage ON SCHEMA graphile_worker TO postgraphile;

ALTER FUNCTION graphile_worker.add_job SECURITY DEFINER;

-- CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE TABLE public.customer (
  id text PRIMARY KEY,
  balance money NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT ON TABLE public.customer TO nologin, authuser;

-- REVOKE ALL ON public.player FROM authuser;
CREATE TYPE public.color_mode_t AS enum (
  'COLOR',
  'BLACK'
);

CREATE TYPE public.job_status_t AS enum (
  'PLACED',
  'EXECUTED',
  'FAILED'
);

CREATE TABLE public.print_job (
  id serial PRIMARY KEY,
  customer_id text NOT NULL REFERENCES public.customer (id) ON DELETE CASCADE,
  filename text NOT NULL,
  color_mode color_mode_t NOT NULL,
  page_range text,
  num_pages smallint NOT NULL,
  num_copies smallint NOT NULL,
  price money NOT NULL,
  status job_status_t NOT NULL DEFAULT 'PLACED',
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT ON TABLE public.print_job TO nologin, authuser;

CREATE TYPE print_config_t AS (
  color_mode color_mode_t,
  page_range text,
  num_pages smallint,
  num_copies smallint
);

