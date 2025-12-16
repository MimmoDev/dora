-- ============================================
-- TROVA IL TUO USER ID
-- ============================================

-- Opzione 1: Dalla tabella auth.users (mostra tutti gli utenti)
select 
  id as user_id,
  email,
  created_at,
  case 
    when email_confirmed_at is not null then '✅ Confermato'
    else '⏳ Non confermato'
  end as stato_email
from auth.users
order by created_at desc;

-- Opzione 2: Dalla tabella profiles (mostra con nome/cognome)
select 
  p.id as user_id,
  u.email,
  p.first_name || ' ' || p.last_name as nome_completo,
  p.role,
  p.profile_completed
from public.profiles p
join auth.users u on u.id = p.id
order by p.created_at desc;

-- ============================================
-- ISTRUZIONI:
-- ============================================
-- 1. Esegui questo script
-- 2. Cerca la tua email nella lista
-- 3. Copia il tuo "user_id" (formato: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
-- 4. Incollalo nello script insert_test_data.sql al posto di 'YOUR_USER_ID'




