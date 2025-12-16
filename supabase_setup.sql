-- ============================================
-- Setup completo per la tabella profiles
-- ============================================

-- 1. Creare la tabella profiles
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  first_name text,
  last_name text,
  phone text,
  role text default 'user',
  created_at timestamptz not null default timezone('utc', now())
);

-- 2. Abilitare Row Level Security (RLS)
alter table public.profiles enable row level security;

-- 3. Policy per SELECT: ogni utente può leggere solo il proprio profilo
create policy "Users can view own profile"
  on public.profiles
  for select
  using (auth.uid() = id);

-- 4. Policy per INSERT: ogni utente può creare solo il proprio profilo
create policy "Users can insert own profile"
  on public.profiles
  for insert
  with check (auth.uid() = id);

-- 5. Policy per UPDATE: ogni utente può aggiornare solo il proprio profilo
create policy "Users can update own profile"
  on public.profiles
  for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- 6. Policy per DELETE: ogni utente può cancellare solo il proprio profilo
create policy "Users can delete own profile"
  on public.profiles
  for delete
  using (auth.uid() = id);

-- 7. [OPZIONALE] Abilitare Realtime per la tabella profiles
-- Esegui questo solo se vuoi ricevere aggiornamenti in tempo reale
alter publication supabase_realtime add table public.profiles;

-- 8. [OPZIONALE] Creare una funzione trigger per creare automaticamente
--    il profilo quando un nuovo utente si registra
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, role, created_at)
  values (new.id, 'user', now());
  return new;
end;
$$ language plpgsql security definer;

-- 9. [OPZIONALE] Creare il trigger per l'auto-creazione del profilo
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ============================================
-- Fine setup
-- ============================================




