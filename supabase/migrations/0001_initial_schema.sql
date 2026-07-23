create type public.member_role as enum ('member', 'council', 'admin');
create type public.feed_post_type as enum ('prompt', 'update', 'resource', 'milestone');
create type public.notification_type as enum ('feed_activity', 'direct_messages', 'travel_flags', 'coaching_nudges');

create table public.cohorts (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    city text,
    starts_on date,
    ends_on date,
    status text not null default 'planned',
    created_at timestamptz not null default now()
);

create table public.member_profiles (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null unique references auth.users(id) on delete cascade,
    role public.member_role not null default 'member',
    name text not null,
    title text not null default '',
    company text not null default '',
    city text not null default '',
    cohort_id uuid references public.cohorts(id),
    function text not null default '',
    challenge text not null default '',
    email text not null,
    onboarding_completed_at timestamptz,
    is_active boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table public.affinity_labels (
    id uuid primary key default gen_random_uuid(),
    name text not null unique,
    created_at timestamptz not null default now()
);

create table public.member_affinity_labels (
    member_profile_id uuid not null references public.member_profiles(id) on delete cascade,
    affinity_label_id uuid not null references public.affinity_labels(id) on delete cascade,
    created_at timestamptz not null default now(),
    primary key (member_profile_id, affinity_label_id)
);

create table public.feed_posts (
    id uuid primary key default gen_random_uuid(),
    author_profile_id uuid not null references public.member_profiles(id) on delete cascade,
    type public.feed_post_type not null,
    title text not null,
    body text not null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table public.feed_replies (
    id uuid primary key default gen_random_uuid(),
    post_id uuid not null references public.feed_posts(id) on delete cascade,
    author_profile_id uuid not null references public.member_profiles(id) on delete cascade,
    body text not null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table public.notification_preferences (
    id uuid primary key default gen_random_uuid(),
    member_profile_id uuid not null references public.member_profiles(id) on delete cascade,
    type public.notification_type not null,
    push_enabled boolean not null default true,
    in_app_enabled boolean not null default true,
    email_enabled boolean not null default false,
    sms_enabled boolean not null default false,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (member_profile_id, type)
);

alter table public.cohorts enable row level security;
alter table public.member_profiles enable row level security;
alter table public.affinity_labels enable row level security;
alter table public.member_affinity_labels enable row level security;
alter table public.feed_posts enable row level security;
alter table public.feed_replies enable row level security;
alter table public.notification_preferences enable row level security;

create policy "Authenticated users can read cohorts"
on public.cohorts for select
to authenticated
using (true);

create policy "Authenticated users can read active member profiles"
on public.member_profiles for select
to authenticated
using (is_active = true);

create policy "Members can update their own profile"
on public.member_profiles for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "Authenticated users can read affinity labels"
on public.affinity_labels for select
to authenticated
using (true);

create policy "Authenticated users can read member affinity labels"
on public.member_affinity_labels for select
to authenticated
using (true);

create policy "Members can manage their own affinity labels"
on public.member_affinity_labels for all
to authenticated
using (
    exists (
        select 1
        from public.member_profiles
        where member_profiles.id = member_affinity_labels.member_profile_id
        and member_profiles.user_id = auth.uid()
    )
)
with check (
    exists (
        select 1
        from public.member_profiles
        where member_profiles.id = member_affinity_labels.member_profile_id
        and member_profiles.user_id = auth.uid()
    )
);

create policy "Authenticated users can read feed posts"
on public.feed_posts for select
to authenticated
using (true);

create policy "Members can create their own feed posts"
on public.feed_posts for insert
to authenticated
with check (
    exists (
        select 1
        from public.member_profiles
        where member_profiles.id = feed_posts.author_profile_id
        and member_profiles.user_id = auth.uid()
    )
);

create policy "Authenticated users can read feed replies"
on public.feed_replies for select
to authenticated
using (true);

create policy "Members can create their own feed replies"
on public.feed_replies for insert
to authenticated
with check (
    exists (
        select 1
        from public.member_profiles
        where member_profiles.id = feed_replies.author_profile_id
        and member_profiles.user_id = auth.uid()
    )
);

create policy "Members can read their own notification preferences"
on public.notification_preferences for select
to authenticated
using (
    exists (
        select 1
        from public.member_profiles
        where member_profiles.id = notification_preferences.member_profile_id
        and member_profiles.user_id = auth.uid()
    )
);

create policy "Members can update their own notification preferences"
on public.notification_preferences for update
to authenticated
using (
    exists (
        select 1
        from public.member_profiles
        where member_profiles.id = notification_preferences.member_profile_id
        and member_profiles.user_id = auth.uid()
    )
)
with check (
    exists (
        select 1
        from public.member_profiles
        where member_profiles.id = notification_preferences.member_profile_id
        and member_profiles.user_id = auth.uid()
    )
);
