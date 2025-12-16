-- ============================================
-- DEBUG E FIX COMPLETO DEL TRIGGER
-- ============================================

-- STEP 1: Rimuovi TUTTO quello che può dare conflitto
-- ============================================

-- Disabilita e rimuovi tutti i trigger esistenti
drop trigger if exists on_auth_user_created on auth.users;
drop trigger if exists handle_new_user_trigger on auth.users;
drop trigger if exists create_profile_on_signup on auth.users;

-- Rimuovi tutte le funzioni
drop function if exists public.handle_new_user() cascade;
drop function if exists public.create_profile_for_new_user() cascade;

-- STEP 2: Verifica che la tabella profiles sia corretta
-- ============================================

-- Mostra la struttura della tabella
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'profiles'
ORDER BY ordinal_position;

-- STEP 3: Crea una funzione trigger SEMPLICE e SICURA
-- ============================================

create or replace function public.handle_new_user()
returns trigger
security definer
language plpgsql
as $$
begin
  -- Inserisci il profilo base con gestione conflitti
  insert into public.profiles (id, role, created_at)
  values (new.id, 'user', timezone('utc', now()))
  on conflict (id) do nothing;
  
  return new;
exception
  when others then
    -- Se c'è un errore, logga ma non bloccare la registrazione
    raise warning 'Errore creazione profilo per user %: %', new.id, sqlerrm;
    return new;
end;
$$;

-- STEP 4: Crea il trigger
-- ============================================

create trigger on_auth_user_created
  after insert on auth.users
  for each row
  execute function public.handle_new_user();

-- STEP 5: Verifica che tutto sia ok
-- ============================================

-- Mostra il trigger
SELECT 
  trigger_name, 
  event_manipulation, 
  event_object_table,
  action_statement
FROM information_schema.triggers 
WHERE trigger_name = 'on_auth_user_created';

-- Mostra la funzione
SELECT 
  routine_name, 
  routine_type,
  security_type
FROM information_schema.routines 
WHERE routine_name = 'handle_new_user';

-- STEP 6: Test manuale (OPZIONALE - per testare la funzione)
-- ============================================
-- DECOMMENTARE SOLO PER TESTARE:
-- 
-- do $$
-- declare
--   test_uuid uuid := gen_random_uuid();
-- begin
--   -- Simula inserimento diretto
--   insert into public.profiles (id, role, created_at)
--   values (test_uuid, 'user', now());
--   
--   raise notice 'Test OK: Profilo creato con id %', test_uuid;
--   
--   -- Pulisci il test
--   delete from public.profiles where id = test_uuid;
-- end $$;




