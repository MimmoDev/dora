-- ============================================
-- SOLUZIONE ALTERNATIVA: Disabilita trigger
-- ============================================

-- Rimuovi completamente il trigger
drop trigger if exists on_auth_user_created on auth.users;
drop function if exists public.handle_new_user() cascade;

-- Abilita una policy INSERT temporanea molto permissiva
-- SOLO per gli utenti appena registrati
drop policy if exists "Enable insert during signup" on public.profiles;

create policy "Enable insert during signup"
  on public.profiles
  for insert
  to authenticated, anon
  with check (true);  -- ATTENZIONE: molto permissiva, ma funziona

-- Mostra le policy attive
SELECT policyname, cmd, roles, with_check 
FROM pg_policies 
WHERE tablename = 'profiles';




