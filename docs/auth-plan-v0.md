# 2CI Auth Plan v0

2CI v1 should be private and invite-only.

## Product Contract

- No public signup.
- Members enter through an invitation or acceptance flow.
- Magic link is the preferred v1 login method.
- Email/password is acceptable but not preferred for the first experience.
- LinkedIn OAuth is a later profile-seeding enhancement, not a blocker for Supabase-backed data work.

## Supabase Setup

- Use Supabase Auth for user identity.
- Create invited users in Supabase Auth.
- Store member-facing profile data in `public.member_profiles`.
- Link `public.member_profiles.user_id` to `auth.users.id`.
- Add `twoci://auth-callback` to allowed redirect URLs before testing full iOS magic-link deep linking.

## Security Notes

- The iOS app may use the publishable key.
- The iOS app must not include the `service_role` key.
- Admin tooling and server jobs that need elevated access belong in this backend repo.
