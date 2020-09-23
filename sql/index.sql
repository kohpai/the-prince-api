CREATE ROLE nologin;

CREATE ROLE authuser;

GRANT nologin TO postgraphile;

GRANT authuser TO postgraphile;

GRANT ALL ON DATABASE postgraphile TO postgraphile;

-- after schema creation and before function creation
ALTER DEFAULT privileges REVOKE EXECUTE ON functions FROM public;

GRANT usage ON SCHEMA public TO nologin, authuser;

-- CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE TABLE public.customer (
  id text PRIMARY KEY,
  balance money NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT ON TABLE public.customer TO nologin, authuser;

-- REVOKE ALL ON public.player FROM authuser;
CREATE TYPE public.color_mode AS enum (
  'COLOR',
  'BLACK'
);

CREATE TABLE public.print_job (
  id serial PRIMARY KEY,
  customer_id text NOT NULL REFERENCES public.customer (id) ON DELETE CASCADE,
  filename text NOT NULL,
  num_pages smallint NOT NULL,
  color color_mode NOT NULL,
  price money NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT ON TABLE public.print_job TO nologin, authuser;
