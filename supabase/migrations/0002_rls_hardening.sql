-- 0002_rls_hardening.sql
--
-- Closes gaps found in a review of the 0001 policy set, October 2026.
--
-- Covered here:
--   1. Members can no longer edit privileged columns on their own profile
--      (role, is_active, cohort_id, email, user_id).
--   2. Members can read their own profile even when is_active is false.
--   3. Members can create their own notification preference rows.
--   4. Members can edit and delete their own feed posts and replies.
--   5. Admins can delete any post or reply, so moderation is possible
--      without dashboard access.
--
-- NOT covered here, because it is not a database setting:
--   Public signup must be disabled in the Supabase dashboard under
--   Authentication. Every read policy in this schema grants access to the
--   `authenticated` role, so an open signup form means anyone can create an
--   account and read the full member directory and feed. The auth plan states
--   no public signup as a product contract; nothing in SQL enforces it.
--   Verify that toggle before any real member data is loaded.
--
-- Also deliberately NOT added:
--   An insert policy on member_profiles. 2CI is invite-only. Profile rows are
--   created by an admin when a member is invited, and the member completes the
--   row during onboarding via the existing update policy. Adding a member-facing
--   insert policy would let any authenticated user mint a profile.
--
--   A member-facing path to change `role`. Role changes are an admin action and
--   should go through the Supabase dashboard or a server-side job using the
--   service_role key. Admins are also `authenticated`, so a policy permitting it
--   would reopen the escalation hole this migration closes.

begin;

-- ---------------------------------------------------------------------------
-- 1. Lock down which columns a member may update on their own profile
-- ---------------------------------------------------------------------------
-- RLS policies gate which ROWS are reachable, not which COLUMNS. The 0001
-- policy "Members can update their own profile" correctly limits a member to
-- their own row, but left every column on that row writable, including `role`.
-- A member could set their own role to 'admin' through the API.
--
-- Column-level privileges are the right tool. Revoke blanket update, then grant
-- update on the member-editable columns only.

revoke update on public.member_profiles from authenticated;

grant update (
    name,
    title,
    company,
    city,
    function,
    challenge,
    onboarding_completed_at,
    updated_at
) on public.member_profiles to authenticated;

-- `email` is intentionally excluded. It is the identity tied to auth.users and
-- should change through the auth system, not the profile row.

-- ---------------------------------------------------------------------------
-- 2. Let members read their own profile regardless of is_active
-- ---------------------------------------------------------------------------
-- The 0001 select policy is scoped to `is_active = true`. A deactivated member
-- who still has a valid session cannot load their own profile, which means the
-- app has no row to work with and falls through to its mock data path.
-- Policies are permissive and OR together, so this widens access by exactly
-- one row: the caller's own.

create policy "Members can always read their own profile"
on public.member_profiles for select
to authenticated
using (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- 3. Admin helper
-- ---------------------------------------------------------------------------
-- security definer so the function can read member_profiles without being
-- filtered by the very policies that call it, which would otherwise recurse.
-- search_path is pinned, per Supabase guidance for definer functions.

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (
        select 1
        from public.member_profiles
        where user_id = auth.uid()
        and role = 'admin'
    );
$$;

revoke execute on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Notification preferences: members can create their own rows
-- ---------------------------------------------------------------------------
-- 0001 granted select and update but no insert, so a newly invited member has
-- no preference rows and no way to create any. SupabaseDataService currently
-- masks this by substituting mock preferences when the query returns empty.

create policy "Members can create their own notification preferences"
on public.notification_preferences for insert
to authenticated
with check (
    exists (
        select 1
        from public.member_profiles
        where member_profiles.id = notification_preferences.member_profile_id
        and member_profiles.user_id = auth.uid()
    )
);

-- ---------------------------------------------------------------------------
-- 5. Feed posts: authors can edit and delete their own
-- ---------------------------------------------------------------------------
-- 0001 allowed select and insert only. Posts were permanent and uneditable by
-- anyone, including admins, with no moderation path outside the dashboard.

create policy "Members can update their own feed posts"
on public.feed_posts for update
to authenticated
using (
    exists (
        select 1
        from public.member_profiles
        where member_profiles.id = feed_posts.author_profile_id
        and member_profiles.user_id = auth.uid()
    )
)
with check (
    exists (
        select 1
        from public.member_profiles
        where member_profiles.id = feed_posts.author_profile_id
        and member_profiles.user_id = auth.uid()
    )
);

create policy "Members can delete their own feed posts"
on public.feed_posts for delete
to authenticated
using (
    exists (
        select 1
        from public.member_profiles
        where member_profiles.id = feed_posts.author_profile_id
        and member_profiles.user_id = auth.uid()
    )
);

create policy "Admins can delete any feed post"
on public.feed_posts for delete
to authenticated
using (public.is_admin());

-- Authors may edit body and title but must not be able to reassign authorship
-- or backdate a post.

revoke update on public.feed_posts from authenticated;
grant update (title, body, updated_at) on public.feed_posts to authenticated;

-- ---------------------------------------------------------------------------
-- 6. Feed replies: same treatment
-- ---------------------------------------------------------------------------

create policy "Members can update their own feed replies"
on public.feed_replies for update
to authenticated
using (
    exists (
        select 1
        from public.member_profiles
        where member_profiles.id = feed_replies.author_profile_id
        and member_profiles.user_id = auth.uid()
    )
)
with check (
    exists (
        select 1
        from public.member_profiles
        where member_profiles.id = feed_replies.author_profile_id
        and member_profiles.user_id = auth.uid()
    )
);

create policy "Members can delete their own feed replies"
on public.feed_replies for delete
to authenticated
using (
    exists (
        select 1
        from public.member_profiles
        where member_profiles.id = feed_replies.author_profile_id
        and member_profiles.user_id = auth.uid()
    )
);

create policy "Admins can delete any feed reply"
on public.feed_replies for delete
to authenticated
using (public.is_admin());

revoke update on public.feed_replies from authenticated;
grant update (body, updated_at) on public.feed_replies to authenticated;

commit;

-- ---------------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------------
-- Run these in the SQL editor after applying, as a normal member, not as
-- service_role. The dashboard SQL editor runs as a superuser and bypasses RLS
-- entirely, so it will NOT reproduce what a member sees.
--
-- Expected after this migration, signed in as a plain member:
--
--   update member_profiles set role = 'admin' where user_id = auth.uid();
--     -> ERROR: permission denied for table member_profiles
--        (Postgres reports the table, not the column, when a statement touches
--        a column outside the granted set. The grant is still column-level.)
--
--   update member_profiles set title = 'VP Operations' where user_id = auth.uid();
--     -> 1 row updated
--
--   delete from feed_posts where id = '<another member's post>';
--     -> 0 rows affected
--
--   delete from feed_posts where id = '<your own post>';
--     -> 1 row deleted
