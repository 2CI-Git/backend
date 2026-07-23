# 2CI Backend

Backend source of truth for the 2CI platform.

This repo owns database schema, Supabase migrations, seeds, backend/admin utilities, and future server-side jobs. The iOS app should consume the backend contract, not own it.

## Current Stack

- Supabase Postgres
- Supabase Auth
- Supabase Row Level Security
- Native iOS client in `2CI-Git/iOS`

## Structure

```text
supabase/
  migrations/
    0001_initial_schema.sql
  seeds/
    dev_seed.sql
docs/
  auth-plan-v0.md
  data-model-v0.md
```

## Local Workflow

Run migrations from the Supabase dashboard SQL editor for now. Once the Supabase CLI is adopted, these files can become the CLI migration source.

`supabase/seeds/dev_seed.sql` currently targets the first 2CI test member created in Supabase Auth. Treat it as a development seed, not a reusable production import.

Never commit Supabase `service_role` keys or other production secrets.
