-- Read-only checks for the Firebase -> Supabase sync errors.
-- Run in the Supabase SQL Editor; nothing here changes data.

-- 1. Supabase accounts (the app writes auth.uid() into user_id).
select id, email, created_at from auth.users order by created_at;

-- 2. Who owns the rows. Rows whose user_id is not a Supabase user id
--    (e.g. a 28-char Firebase uid) are invisible to their owner under RLS.
select 'incomes' as table_name, user_id, count(*) from public.incomes group by user_id
union all
select 'expenses', user_id, count(*) from public.expenses group by user_id
order by 1, 3 desc;

-- 3. RLS policies on both tables.
select tablename, policyname, cmd, roles, qual, with_check
from pg_policies
where schemaname = 'public' and tablename in ('incomes', 'expenses')
order by tablename, cmd;

-- 4. Indexes / constraints: upsert(onConflict: 'firebase_id') needs a
--    unique index on firebase_id.
select tablename, indexname, indexdef
from pg_indexes
where schemaname = 'public' and tablename in ('incomes', 'expenses');

-- 5. Duplicate firebase_id values that would block a unique index.
select 'expenses' as table_name, firebase_id, count(*)
from public.expenses where firebase_id is not null
group by firebase_id having count(*) > 1
union all
select 'incomes', firebase_id, count(*)
from public.incomes where firebase_id is not null
group by firebase_id having count(*) > 1;

-- 6. Column types of user_id (uuid vs text decides how ids compare).
select table_name, column_name, data_type
from information_schema.columns
where table_schema = 'public'
  and table_name in ('incomes', 'expenses')
  and column_name in ('user_id', 'firebase_id');
