-- ============================================
-- Aggiunta flag profile_completed
-- ============================================

-- 1. Aggiungi la colonna profile_completed alla tabella profiles
alter table public.profiles 
add column if not exists profile_completed boolean default false;

-- 2. Aggiorna i profili esistenti (se ce ne sono) a false
update public.profiles 
set profile_completed = false 
where profile_completed is null;

-- 3. Verifica la struttura della tabella
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'profiles'
ORDER BY ordinal_position;

-- 4. [OPZIONALE] Se vuoi che i profili con dati siano automaticamente "completati"
-- Decommenta e esegui:
-- update public.profiles 
-- set profile_completed = true 
-- where first_name is not null 
--   and last_name is not null;




