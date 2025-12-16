-- ============================================
-- SETUP COMPLETO SISTEMA APPUNTAMENTI
-- Esegui questo script nel SQL Editor di Supabase
-- ============================================

-- ============================================
-- 1. CREAZIONE TABELLE
-- ============================================

-- Tabella Abbonamenti
create table if not exists public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade not null,
  subscription_type text not null default 'mensile',
  status text not null default 'inactive' check (status in ('active', 'inactive', 'expired', 'cancelled')),
  start_date timestamptz,
  end_date timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  activated_by uuid references public.profiles(id)
);

-- Indice unico: un utente può avere un solo abbonamento attivo
create unique index if not exists idx_unique_active_subscription 
  on public.subscriptions(user_id) 
  where (status = 'active');

-- Indici per performance
create index if not exists idx_subscriptions_user_id on public.subscriptions(user_id);
create index if not exists idx_subscriptions_status on public.subscriptions(status);
create index if not exists idx_subscriptions_dates on public.subscriptions(start_date, end_date);

-- Tabella Appuntamenti
create table if not exists public.appointments (
  id uuid primary key default gen_random_uuid(),
  appointment_date date not null,
  appointment_time time not null,
  duration_minutes int not null default 60,
  max_participants int not null default 10,
  current_participants int not null default 0,
  title text not null,
  description text,
  created_by uuid references public.profiles(id) not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint valid_participants check (current_participants <= max_participants)
);

-- Indici per performance
create index if not exists idx_appointments_date on public.appointments(appointment_date);
create index if not exists idx_appointments_datetime on public.appointments(appointment_date, appointment_time);

-- Tabella Prenotazioni
create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade not null,
  appointment_id uuid references public.appointments(id) on delete cascade not null,
  status text not null default 'confirmed' check (status in ('confirmed', 'cancelled', 'completed')),
  created_at timestamptz not null default timezone('utc', now()),
  cancelled_at timestamptz,
  constraint unique_booking unique (user_id, appointment_id)
);

-- Indici per performance
create index if not exists idx_bookings_user_id on public.bookings(user_id);
create index if not exists idx_bookings_appointment_id on public.bookings(appointment_id);
create index if not exists idx_bookings_status on public.bookings(status);

-- ============================================
-- 2. FUNZIONI HELPER
-- ============================================

-- Conta prenotazioni settimanali
create or replace function public.count_weekly_bookings(p_user_id uuid, p_week_start date)
returns int
language sql
security definer
stable
as $$
  select count(*)::int
  from public.bookings b
  join public.appointments a on a.id = b.appointment_id
  where b.user_id = p_user_id
    and b.status = 'confirmed'
    and a.appointment_date >= p_week_start
    and a.appointment_date < p_week_start + interval '7 days';
$$;

-- Verifica se un utente può prenotare
create or replace function public.can_user_book(p_user_id uuid, p_appointment_date date)
returns boolean
language plpgsql
security definer
stable
as $$
declare
  v_has_active_subscription boolean;
  v_week_start date;
  v_weekly_count int;
begin
  -- Verifica abbonamento attivo
  select exists(
    select 1 from public.subscriptions
    where user_id = p_user_id
      and status = 'active'
      and (start_date is null or start_date <= now())
      and (end_date is null or end_date >= now())
  ) into v_has_active_subscription;
  
  if not v_has_active_subscription then
    return false;
  end if;
  
  -- Calcola inizio settimana (lunedì)
  v_week_start := date_trunc('week', p_appointment_date::timestamp)::date;
  
  -- Conta prenotazioni della settimana
  v_weekly_count := public.count_weekly_bookings(p_user_id, v_week_start);
  
  -- Verifica limite settimanale (3 appuntamenti)
  return v_weekly_count < 3;
end;
$$;

-- ============================================
-- 3. TRIGGER PER AGGIORNAMENTO PARTECIPANTI
-- ============================================

create or replace function public.update_appointment_participants()
returns trigger
language plpgsql
security definer
as $$
begin
  if (TG_OP = 'INSERT' and NEW.status = 'confirmed') then
    -- Incrementa partecipanti
    update public.appointments
    set current_participants = current_participants + 1,
        updated_at = timezone('utc', now())
    where id = NEW.appointment_id;
    
  elsif (TG_OP = 'UPDATE') then
    if (OLD.status = 'confirmed' and NEW.status != 'confirmed') then
      -- Decrementa partecipanti (cancellazione)
      update public.appointments
      set current_participants = current_participants - 1,
          updated_at = timezone('utc', now())
      where id = NEW.appointment_id;
    elsif (OLD.status != 'confirmed' and NEW.status = 'confirmed') then
      -- Incrementa partecipanti (riconferma)
      update public.appointments
      set current_participants = current_participants + 1,
          updated_at = timezone('utc', now())
      where id = NEW.appointment_id;
    end if;
    
  elsif (TG_OP = 'DELETE' and OLD.status = 'confirmed') then
    -- Decrementa partecipanti
    update public.appointments
    set current_participants = current_participants - 1,
        updated_at = timezone('utc', now())
    where id = OLD.appointment_id;
  end if;
  
  return coalesce(NEW, OLD);
end;
$$;

drop trigger if exists trg_update_appointment_participants on public.bookings;
create trigger trg_update_appointment_participants
  after insert or update or delete on public.bookings
  for each row
  execute function public.update_appointment_participants();

-- ============================================
-- 4. ROW LEVEL SECURITY (RLS)
-- ============================================

-- Abilita RLS
alter table public.subscriptions enable row level security;
alter table public.appointments enable row level security;
alter table public.bookings enable row level security;

-- SUBSCRIPTIONS: Policies
drop policy if exists "Users can view own subscription" on public.subscriptions;
create policy "Users can view own subscription"
  on public.subscriptions for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Admins can manage all subscriptions" on public.subscriptions;
create policy "Admins can manage all subscriptions"
  on public.subscriptions for all
  to authenticated
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

-- APPOINTMENTS: Policies
drop policy if exists "Everyone can view appointments" on public.appointments;
create policy "Everyone can view appointments"
  on public.appointments for select
  to authenticated
  using (true);

drop policy if exists "Admins can manage appointments" on public.appointments;
create policy "Admins can manage appointments"
  on public.appointments for all
  to authenticated
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

-- BOOKINGS: Policies
drop policy if exists "Users can view own bookings" on public.bookings;
create policy "Users can view own bookings"
  on public.bookings for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can create own bookings" on public.bookings;
create policy "Users can create own bookings"
  on public.bookings for insert
  to authenticated
  with check (
    auth.uid() = user_id
    and public.can_user_book(user_id, (
      select appointment_date from public.appointments where id = appointment_id
    ))
  );

drop policy if exists "Users can cancel own bookings" on public.bookings;
create policy "Users can cancel own bookings"
  on public.bookings for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Admins can manage all bookings" on public.bookings;
create policy "Admins can manage all bookings"
  on public.bookings for all
  to authenticated
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

-- ============================================
-- 5. VERIFICA FINALE
-- ============================================

select 'Setup completato con successo!' as status;

-- Mostra tabelle create
select table_name
from information_schema.tables
where table_schema = 'public'
  and table_name in ('subscriptions', 'appointments', 'bookings')
order by table_name;




