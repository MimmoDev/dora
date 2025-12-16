-- ============================================
-- SCHEMA SISTEMA CHECK-IN V2
-- Con password modificabile da admin
-- ============================================

-- PRIMA: Pulisci eventuali installazioni precedenti
drop function if exists public.validate_check_in(uuid, text);
drop table if exists public.check_ins cascade;
drop table if exists public.gym_settings cascade;

-- ============================================
-- 1. TABELLA GYM_SETTINGS (per password QR)
-- ============================================
create table public.gym_settings (
  id uuid primary key default gen_random_uuid(),
  setting_key text unique not null,
  setting_value text not null,
  description text,
  updated_at timestamptz not null default timezone('utc', now()),
  updated_by uuid references public.profiles(id)
);

-- Inserisci la password del QR code
insert into public.gym_settings (setting_key, setting_value, description)
values 
  ('qr_code_password', 'DORA2025GYM', 'Password del QR code per il check-in in palestra'),
  ('check_in_early_minutes', '30', 'Minuti di anticipo consentiti per il check-in'),
  ('check_in_late_minutes', '15', 'Minuti di ritardo consentiti per il check-in');

-- ============================================
-- 2. TABELLA CHECK-INS
-- ============================================
create table public.check_ins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade not null,
  booking_id uuid references public.bookings(id) on delete set null,
  appointment_id uuid references public.appointments(id) on delete set null,
  checked_in_at timestamptz not null default timezone('utc', now()),
  status text not null check (status in ('valid', 'late', 'early', 'no_booking', 'wrong_day', 'invalid_qr')),
  notes text,
  created_at timestamptz not null default timezone('utc', now())
);

-- Indici
create index idx_check_ins_user_id on public.check_ins(user_id);
create index idx_check_ins_booking_id on public.check_ins(booking_id);
create index idx_check_ins_appointment_id on public.check_ins(appointment_id);
create index idx_check_ins_date on public.check_ins(checked_in_at);
create index idx_check_ins_status on public.check_ins(status);

-- ============================================
-- 3. FUNZIONE: Ottieni impostazione
-- ============================================
create or replace function public.get_gym_setting(p_key text)
returns text
language sql
security definer
stable
as $$
  select setting_value from public.gym_settings where setting_key = p_key;
$$;

-- ============================================
-- 4. FUNZIONE: Valida check-in
-- ============================================
create or replace function public.validate_check_in(
  p_user_id uuid,
  p_qr_password text
)
returns json
language plpgsql
security definer
as $$
declare
  v_correct_password text;
  v_now timestamptz := timezone('utc', now());
  v_today date := v_now::date;
  v_current_time time := v_now::time;
  v_booking record;
  v_time_diff interval;
  v_early_minutes int;
  v_late_minutes int;
begin
  -- Ottieni password corretta
  v_correct_password := public.get_gym_setting('qr_code_password');
  
  -- Verifica password QR
  if p_qr_password != v_correct_password then
    return json_build_object(
      'valid', false,
      'status', 'invalid_qr',
      'message', 'QR Code non valido'
    );
  end if;
  
  -- Ottieni impostazioni temporali
  v_early_minutes := (public.get_gym_setting('check_in_early_minutes'))::int;
  v_late_minutes := (public.get_gym_setting('check_in_late_minutes'))::int;
  
  -- Cerca prenotazione per oggi
  select b.*, a.*
  into v_booking
  from public.bookings b
  join public.appointments a on a.id = b.appointment_id
  where b.user_id = p_user_id
    and b.status = 'confirmed'
    and a.appointment_date = v_today
  order by a.appointment_time
  limit 1;
  
  -- Nessuna prenotazione per oggi
  if not found then
    return json_build_object(
      'valid', false,
      'status', 'no_booking',
      'message', 'Non hai prenotazioni per oggi'
    );
  end if;
  
  -- Calcola differenza di tempo
  v_time_diff := v_current_time - v_booking.appointment_time::time;
  
  -- Troppo presto
  if v_time_diff < make_interval(mins => -v_early_minutes) then
    return json_build_object(
      'valid', false,
      'status', 'early',
      'message', format('Sei troppo in anticipo. Puoi timbrare %s minuti prima della lezione.', v_early_minutes),
      'appointment_time', v_booking.appointment_time,
      'appointment_title', v_booking.title,
      'booking_id', v_booking.id,
      'appointment_id', v_booking.appointment_id
    );
  end if;
  
  -- Troppo tardi
  if v_time_diff > make_interval(mins => v_late_minutes) then
    return json_build_object(
      'valid', false,
      'status', 'late',
      'message', format('Sei in ritardo. Puoi timbrare fino a %s minuti dopo l''inizio.', v_late_minutes),
      'appointment_time', v_booking.appointment_time,
      'appointment_title', v_booking.title,
      'booking_id', v_booking.id,
      'appointment_id', v_booking.appointment_id
    );
  end if;
  
  -- Check-in valido!
  return json_build_object(
    'valid', true,
    'status', 'valid',
    'message', 'Check-in effettuato con successo!',
    'appointment_time', v_booking.appointment_time,
    'appointment_title', v_booking.title,
    'appointment_description', v_booking.description,
    'booking_id', v_booking.id,
    'appointment_id', v_booking.appointment_id
  );
end;
$$;

-- ============================================
-- 5. ROW LEVEL SECURITY
-- ============================================

alter table public.check_ins enable row level security;
alter table public.gym_settings enable row level security;

-- CHECK_INS: Policies
create policy "Users can view own check-ins"
  on public.check_ins for select
  to authenticated
  using (auth.uid() = user_id);

create policy "Users can create own check-ins"
  on public.check_ins for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "Admins can view all check-ins"
  on public.check_ins for select
  to authenticated
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

-- GYM_SETTINGS: Policies
create policy "Everyone can read gym settings"
  on public.gym_settings for select
  to authenticated
  using (true);

create policy "Only admins can modify gym settings"
  on public.gym_settings for all
  to authenticated
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  )
  with check (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

-- ============================================
-- 6. VERIFICA FINALE
-- ============================================
select '✅ Sistema check-in V2 installato con successo!' as status;

-- Mostra impostazioni
select 
  setting_key,
  setting_value,
  description
from public.gym_settings
order by setting_key;

-- Verifica funzione
select 
  routine_name,
  '✅ Funzione creata correttamente' as status
from information_schema.routines
where routine_schema = 'public' 
  and routine_name = 'validate_check_in';




