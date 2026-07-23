-- Development seed for the current 2CI Supabase project.
-- Assumes auth user 4ec96bab-cd41-4cac-abad-7c0342faa9ab already exists.

do $$
declare
    cohort_id_value uuid;
    member_profile_id_value uuid;
    feed_post_id_value uuid;
begin
    insert into public.cohorts (name, city, starts_on, ends_on, status)
    values ('Scottsdale 2026', 'Scottsdale, AZ', '2026-01-01', '2026-12-31', 'active')
    on conflict do nothing;

    select id into cohort_id_value
    from public.cohorts
    where name = 'Scottsdale 2026'
    limit 1;

    update public.member_profiles
    set cohort_id = cohort_id_value,
        city = 'Seattle, WA',
        function = 'Design',
        updated_at = now()
    where user_id = '4ec96bab-cd41-4cac-abad-7c0342faa9ab';

    select id into member_profile_id_value
    from public.member_profiles
    where user_id = '4ec96bab-cd41-4cac-abad-7c0342faa9ab'
    limit 1;

    insert into public.affinity_labels (name)
    values ('Design'), ('AI'), ('Seattle'), ('Product')
    on conflict (name) do nothing;

    insert into public.member_affinity_labels (member_profile_id, affinity_label_id)
    select member_profile_id_value, affinity_labels.id
    from public.affinity_labels
    where name in ('Design', 'AI', 'Seattle', 'Product')
    on conflict do nothing;

    insert into public.notification_preferences (member_profile_id, type, push_enabled, in_app_enabled, email_enabled, sms_enabled)
    values
        (member_profile_id_value, 'feed_activity', true, true, false, false),
        (member_profile_id_value, 'direct_messages', true, true, true, false),
        (member_profile_id_value, 'travel_flags', true, true, true, true),
        (member_profile_id_value, 'coaching_nudges', true, true, true, false)
    on conflict (member_profile_id, type) do nothing;

    insert into public.feed_posts (author_profile_id, type, title, body)
    values (
        member_profile_id_value,
        'update',
        'Kicking off Scottsdale 2026',
        'Excited to start shaping the 2CI app around the real Scottsdale 2026 member experience.'
    )
    returning id into feed_post_id_value;

    insert into public.feed_replies (post_id, author_profile_id, body)
    values (
        feed_post_id_value,
        member_profile_id_value,
        'First real Supabase-backed reply is alive.'
    );
end $$;
