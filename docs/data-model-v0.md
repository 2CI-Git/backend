# 2CI Data Model v0

This is the first backend contract for the 2CI app.

## Core Tables

- `cohorts`
- `member_profiles`
- `affinity_labels`
- `member_affinity_labels`
- `feed_posts`
- `feed_replies`
- `notification_preferences`

## v1 Principles

- Members are invite-only.
- Auth identity lives in `auth.users`.
- App-visible member data lives in `public.member_profiles`.
- Feed posts and replies are human-created in v1.
- RLS is enabled on every public table used by the app.
- Authenticated members can read the community surface.
- Members can write only as themselves.

## Ownership

The canonical schema and seeds live in this backend repo. The iOS repo may contain client models and services, but should not be the long-term source of truth for migrations.
