-- ============================================
-- SOLUZIONE DEFINITIVA: Trigger + Policy corretta
-- ============================================

-- PARTE 1: Trigger per auto-creazione profilo
-- ============================================

-- Rimuovi trigger esistente
drop trigger if exists on_auth_user_created on auth.users;
drop function if exists public.handle_new_user();

-- Crea funzione che bypassa RLS (security definer)
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer  -- IMPORTANTE: bypassa le RLS policies
set search_path = public
as $$
begin
  insert into public.profiles (id, role, created_at)
  values (new.id, 'user', now())
  on conflict (id) do nothing;
  return new;
end;
$$;

-- Crea trigger che si attiva DOPO la creazione di un utente
create trigger on_auth_user_created
  after insert on auth.users
  for each row
  execute function public.handle_new_user();


-- PARTE 2: Policy di UPDATE permissiva per i dati extra
-- ============================================

-- Rimuovi vecchie policy di INSERT (il trigger le sostituisce)
drop policy if exists "Users can insert own profile" on public.profiles;
drop policy if exists "profiles_insert_own" on public.profiles;
drop policy if exists "Enable insert for authenticated users" on public.profiles;

-- Mantieni policy di UPDATE per aggiornare i dati extra dopo
drop policy if exists "Users can update own profile" on public.profiles;
drop policy if exists "profiles_update_own" on public.profiles;

create policy "Enable update for users based on id"
  on public.profiles
  for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);


-- PARTE 3: Verifica configurazione
-- ============================================

-- Mostra tutte le policy
SELECT policyname, cmd, qual, with_check 
FROM pg_policies 
WHERE tablename = 'profiles'
ORDER BY cmd;

-- Mostra il trigger
SELECT trigger_name, event_manipulation, event_object_table 
FROM information_schema.triggers 
WHERE trigger_name = 'on_auth_user_created';




