-- ============================================
-- VERIFICA SETUP CHECK-IN
-- ============================================

-- 1. Verifica che la tabella check_ins esista
select 
  table_name,
  case 
    when table_name is not null then '✅ Tabella check_ins creata'
    else '❌ Tabella check_ins NON trovata'
  end as status
from information_schema.tables
where table_schema = 'public' 
  and table_name = 'check_ins';

-- 2. Verifica che la tabella gym_settings esista
select 
  table_name,
  case 
    when table_name is not null then '✅ Tabella gym_settings creata'
    else '❌ Tabella gym_settings NON trovata'
  end as status
from information_schema.tables
where table_schema = 'public' 
  and table_name = 'gym_settings';

-- 3. Verifica la password QR salvata
select 
  setting_key,
  setting_value as password_qr,
  case 
    when setting_value is not null then '✅ Password QR configurata'
    else '❌ Password QR NON configurata'
  end as status
from public.gym_settings
where setting_key = 'qr_code_password';

-- 4. Verifica che la funzione validate_check_in esista
select 
  routine_name,
  routine_type,
  case 
    when routine_name is not null then '✅ Funzione validate_check_in creata'
    else '❌ Funzione validate_check_in NON trovata'
  end as status
from information_schema.routines
where routine_schema = 'public' 
  and routine_name = 'validate_check_in';

-- 5. Mostra i parametri della funzione
select 
  parameter_name,
  data_type,
  parameter_mode
from information_schema.parameters
where specific_schema = 'public'
  and specific_name like '%validate_check_in%'
order by ordinal_position;

-- ============================================
-- RISULTATO ATTESO:
-- ============================================
-- Se tutto è ok, dovresti vedere:
-- ✅ Tabella check_ins creata
-- ✅ Tabella gym_settings creata  
-- ✅ Password QR configurata (DORA2025GYM)
-- ✅ Funzione validate_check_in creata
-- Parametri: p_user_id (uuid), p_qr_password (text)




