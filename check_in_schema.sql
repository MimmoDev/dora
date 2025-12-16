-- ============================================
-- SCHEMA SISTEMA CHECK-IN/TIMBRATURA
-- ============================================

-- 1. TABELLA CHECK-INS
-- ============================================
create table if not exists public.check_ins (
  id uuid primary key default gen_random_uuid(),
  
  -- Riferimenti
  user_id uuid references public.profiles(id) on delete cascade not null,
  booking_id uuid references public.bookings(id) on delete set null,
  appointment_id uuid references public.appointments(id) on delete set null,
  
  -- Data e ora del check-in
  checked_in_at timestamptz not null default timezone('utc', now()),
  
  -- Stato check-in
  status text not null check (status in ('valid', 'late', 'early', 'no_booking', 'wrong_day')),
  
  -- Note
  notes text,
  
  -- Metadati
  created_at timestamptz not null default timezone('utc', now())
);

-- Indici per performance
create index if not exists idx_check_ins_user_id on public.check_ins(user_id);
create index if not exists idx_check_ins_booking_id on public.check_ins(booking_id);
create index if not exists idx_check_ins_appointment_id on public.check_ins(appointment_id);
create index if not exists idx_check_ins_date on public.check_ins(checked_in_at);
create index if not exists idx_check_ins_status on public.check_ins(status);

-- 2. TABELLA GYM_SETTINGS (per salvare il QR code password)
-- ============================================
create table if not exists public.gym_settings (
  id uuid primary key default gen_random_uuid(),
  setting_key text unique not null,
  setting_value text not null,
  updated_at timestamptz not null default timezone('utc', now()),
  updated_by uuid references public.profiles(id)
);

-- Inserisci la password del QR code (modificala come preferisci)
insert into public.gym_settings (setting_key, setting_value)
values ('qr_code_password', 'DORA2025GYM')
on conflict (setting_key) do nothing;

-- 3. FUNZIONE: Verifica check-in valido
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
  v_appointment record;
  v_result json;
  v_time_diff interval;
begin
  -- Verifica password QR
  select setting_value into v_correct_password
  from public.gym_settings
  where setting_key = 'qr_code_password';
  
  if p_qr_password != v_correct_password then
    return json_build_object(
      'valid', false,
      'status', 'invalid_qr',
      'message', 'QR Code non valido'
    );
  end if;
  
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
  
  -- Troppo presto (più di 30 minuti prima)
  if v_time_diff < interval '-30 minutes' then
    return json_build_object(
      'valid', false,
      'status', 'early',
      'message', 'Sei troppo in anticipo. Puoi timbrare 30 minuti prima della lezione.',
      'appointment_time', v_booking.appointment_time,
      'appointment_title', v_booking.title,
      'booking_id', v_booking.id,
      'appointment_id', v_booking.appointment_id
    );
  end if;
  
  -- Troppo tardi (più di 15 minuti dopo l'inizio)
  if v_time_diff > interval '15 minutes' then
    return json_build_object(
      'valid', false,
      'status', 'late',
      'message', 'Sei in ritardo. Puoi timbrare fino a 15 minuti dopo l''inizio.',
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

-- 4. ROW LEVEL SECURITY
-- ============================================

-- Abilita RLS
alter table public.check_ins enable row level security;
alter table public.gym_settings enable row level security;

-- CHECK_INS: Policies
drop policy if exists "Users can view own check-ins" on public.check_ins;
create policy "Users can view own check-ins"
  on public.check_ins for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can create own check-ins" on public.check_ins;
create policy "Users can create own check-ins"
  on public.check_ins for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Admins can view all check-ins" on public.check_ins;
create policy "Admins can view all check-ins"
  on public.check_ins for select
  to authenticated
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

-- GYM_SETTINGS: Policies (solo admin può modificare)
drop policy if exists "Everyone can read gym settings" on public.gym_settings;
create policy "Everyone can read gym settings"
  on public.gym_settings for select
  to authenticated
  using (true);

drop policy if exists "Only admins can modify gym settings" on public.gym_settings;
create policy "Only admins can modify gym settings"
  on public.gym_settings for all
  to authenticated
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

-- 5. VERIFICA FINALE
-- ============================================
select 'Sistema check-in creato con successo!' as status;

-- Mostra password QR attuale
select setting_key, setting_value, updated_at
from public.gym_settings
where setting_key = 'qr_code_password';




