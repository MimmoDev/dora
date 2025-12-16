-- ============================================
-- Policy semplice per creazione profilo al primo login
-- ============================================

-- 1. Disabilita completamente il trigger (non serve più)
drop trigger if exists on_auth_user_created on auth.users;
drop function if exists public.handle_new_user() cascade;

-- 2. Rimuovi tutte le vecchie policy di INSERT
drop policy if exists "Users can insert own profile" on public.profiles;
drop policy if exists "profiles_insert_own" on public.profiles;
drop policy if exists "Enable insert for authenticated users" on public.profiles;
drop policy if exists "Enable insert during signup" on public.profiles;

-- 3. Crea una policy INSERT semplice: utente autenticato può inserire il proprio profilo
create policy "Authenticated users can insert own profile"
  on public.profiles
  for insert
  to authenticated
  with check (auth.uid() = id);

-- 4. Verifica le policy
SELECT policyname, cmd, roles, with_check 
FROM pg_policies 
WHERE tablename = 'profiles'
ORDER BY cmd;




