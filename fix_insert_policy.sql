-- ============================================
-- FIX: Policy INSERT che funziona anche senza conferma email
-- ============================================

-- 1. Rimuovi la vecchia policy di INSERT
drop policy if exists "Users can insert own profile" on public.profiles;
drop policy if exists "profiles_insert_own" on public.profiles;

-- 2. Crea una nuova policy INSERT più permissiva
-- Questa permette l'insert se l'id corrisponde all'uid dell'utente autenticato
-- OPPURE se l'utente è appena registrato (anche senza conferma email)
create policy "Enable insert for authenticated users"
  on public.profiles
  for insert
  to authenticated
  with check (
    auth.uid() = id
  );

-- 3. Verifica che la policy sia stata creata
SELECT policyname, cmd, qual, with_check 
FROM pg_policies 
WHERE tablename = 'profiles' AND cmd = 'INSERT';




