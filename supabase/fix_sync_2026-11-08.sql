-- Fixes the Firebase -> Supabase sync errors found on 2026-11-08:
--   * incomes:  40 rows with user_id '' / 'EMPTY' are hidden by RLS, so the
--               app re-pushes them and the upsert hits incomes_firebase_id_key
--               on rows it may not touch ("violates row-level security").
--   * expenses: 508 rows carry the Firebase uid instead of the Supabase uid,
--               firebase_id has 168 duplicate rows, and there is no unique
--               index, so upsert(onConflict: 'firebase_id') fails.
--
-- The project has a single account (a0cd3671-...), which owns all of this data.
-- Everything runs in one transaction; both tables are copied to the
-- non-API-exposed `backup` schema first so the change can be undone.

begin;

create schema if not exists backup;
create table backup.expenses_20261108 as table public.expenses;
create table backup.incomes_20261108 as table public.incomes;

-- 1. Hand orphaned / Firebase-owned rows to the Supabase account.
update public.incomes
set user_id = 'a0cd3671-0ae7-4c86-a269-c6b2b5ff006b'
where user_id in ('', 'EMPTY');

update public.expenses
set user_id = 'a0cd3671-0ae7-4c86-a269-c6b2b5ff006b'
where user_id = 'IvjTukqNIfTVgtXanYaRFO3axz32';

-- 2. Keep one row per firebase_id: the most recently updated copy.
delete from public.expenses e
using (
  select id,
         row_number() over (
           partition by firebase_id
           order by updated_at desc nulls last, created_at desc nulls last, id
         ) as rn
  from public.expenses
  where firebase_id is not null
) d
where e.id = d.id and d.rn > 1;

-- 3. Let upsert(onConflict: 'firebase_id') work for expenses too.
create unique index expenses_firebase_id_key on public.expenses (firebase_id);

commit;

-- Undo (if ever needed):
--   begin;
--   drop index if exists public.expenses_firebase_id_key;
--   delete from public.expenses; insert into public.expenses select * from backup.expenses_20261108;
--   delete from public.incomes;  insert into public.incomes  select * from backup.incomes_20261108;
--   commit;
