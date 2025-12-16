-- ============================================
-- SCRIPT PER INSERIRE DATI DI TEST
-- ============================================

-- NOTA: Sostituisci 'YOUR_USER_ID' con il tuo vero user ID
-- Lo puoi trovare nella tabella auth.users o profiles

-- ============================================
-- 1. ATTIVA ABBONAMENTO PER L'UTENTE
-- ============================================

-- Prima trova il tuo user_id
-- select id, email from auth.users;

-- Poi inserisci l'abbonamento (sostituisci YOUR_USER_ID)
insert into public.subscriptions (
  user_id,
  subscription_type,
  status,
  start_date,
  end_date,
  created_at,
  updated_at
) values (
  'YOUR_USER_ID',  -- <-- SOSTITUISCI CON IL TUO ID
  'mensile',
  'active',
  now(),
  now() + interval '30 days',
  now(),
  now()
)
on conflict (user_id) 
where (status = 'active')
do update set
  start_date = now(),
  end_date = now() + interval '30 days',
  updated_at = now();

-- ============================================
-- 2. CREA APPUNTAMENTI PER QUESTA SETTIMANA
-- ============================================

-- Lunedì - Yoga Mattina
insert into public.appointments (
  appointment_date,
  appointment_time,
  duration_minutes,
  max_participants,
  current_participants,
  title,
  description,
  created_by
) values (
  date_trunc('week', now())::date,  -- Lunedì di questa settimana
  '09:00',
  60,
  10,
  0,
  'Yoga Mattutino',
  'Sessione di yoga rilassante per iniziare la settimana con energia',
  'YOUR_USER_ID'  -- <-- SOSTITUISCI CON IL TUO ID (o di un admin)
);

-- Lunedì - Pilates Sera
insert into public.appointments (
  appointment_date,
  appointment_time,
  duration_minutes,
  max_participants,
  current_participants,
  title,
  description,
  created_by
) values (
  date_trunc('week', now())::date,
  '18:30',
  60,
  8,
  0,
  'Pilates Serale',
  'Allenamento di pilates per tonificare e rilassare',
  'YOUR_USER_ID'
);

-- Mercoledì - Meditation
insert into public.appointments (
  appointment_date,
  appointment_time,
  duration_minutes,
  max_participants,
  current_participants,
  title,
  description,
  created_by
) values (
  date_trunc('week', now())::date + interval '2 days',  -- Mercoledì
  '19:00',
  45,
  15,
  0,
  'Meditazione Guidata',
  'Sessione di meditazione per trovare pace interiore',
  'YOUR_USER_ID'
);

-- Giovedì - Fitness
insert into public.appointments (
  appointment_date,
  appointment_time,
  duration_minutes,
  max_participants,
  current_participants,
  title,
  description,
  created_by
) values (
  date_trunc('week', now())::date + interval '3 days',  -- Giovedì
  '10:00',
  60,
  12,
  7,  -- Già 7 persone prenotate (per testare la barra)
  'Fitness Total Body',
  'Allenamento completo per tutto il corpo',
  'YOUR_USER_ID'
);

-- Venerdì - Stretching
insert into public.appointments (
  appointment_date,
  appointment_time,
  duration_minutes,
  max_participants,
  current_participants,
  title,
  description,
  created_by
) values (
  date_trunc('week', now())::date + interval '4 days',  -- Venerdì
  '17:00',
  45,
  10,
  9,  -- Quasi pieno (per testare)
  'Stretching e Mobilità',
  'Sessione dedicata allo stretching e al miglioramento della mobilità',
  'YOUR_USER_ID'
);

-- Sabato - Yoga Avanzato (PIENO - per test)
insert into public.appointments (
  appointment_date,
  appointment_time,
  duration_minutes,
  max_participants,
  current_participants,
  title,
  description,
  created_by
) values (
  date_trunc('week', now())::date + interval '5 days',  -- Sabato
  '11:00',
  90,
  6,
  6,  -- PIENO
  'Yoga Avanzato - ESAURITO',
  'Classe di yoga avanzato per praticanti esperti',
  'YOUR_USER_ID'
);

-- ============================================
-- 3. VERIFICA DATI INSERITI
-- ============================================

-- Mostra abbonamento attivo
select 
  id,
  user_id,
  status,
  subscription_type,
  start_date,
  end_date
from public.subscriptions
where status = 'active'
order by created_at desc
limit 5;

-- Mostra appuntamenti creati per questa settimana
select 
  id,
  appointment_date,
  appointment_time,
  title,
  current_participants || '/' || max_participants as "posti",
  case 
    when current_participants >= max_participants then '🔴 PIENO'
    when current_participants::float / max_participants > 0.7 then '🟡 Quasi pieno'
    else '🟢 Disponibile'
  end as stato
from public.appointments
where appointment_date >= date_trunc('week', now())::date
  and appointment_date < date_trunc('week', now())::date + interval '7 days'
order by appointment_date, appointment_time;

select '✅ Dati di test inseriti con successo!' as status;




