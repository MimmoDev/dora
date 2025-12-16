-- ============================================
-- FIX: Rimuovi trigger e ricrea correttamente
-- ============================================

-- 1. Rimuovi il trigger esistente
drop trigger if exists on_auth_user_created on auth.users;

-- 2. Rimuovi la funzione esistente
drop function if exists public.handle_new_user();

-- 3. Ricrea la funzione con gestione errori
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, role, created_at)
  values (new.id, 'user', now())
  on conflict (id) do nothing;
  return new;
end;
$$;

-- 4. Ricrea il trigger
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================
-- VERIFICA: Controlla che tutto sia ok
-- ============================================

-- Mostra il trigger creato
SELECT trigger_name, event_manipulation, event_object_table 
FROM information_schema.triggers 
WHERE trigger_name = 'on_auth_user_created';

-- Mostra la funzione
SELECT routine_name, routine_type 
FROM information_schema.routines 
WHERE routine_name = 'handle_new_user';




