-- ============================================
-- SCHEMA COMPLETO PER SISTEMA APPUNTAMENTI
-- ============================================

-- 1. TABELLA ABBONAMENTI
-- ============================================
create table if not exists public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade not null,
  
  -- Tipo abbonamento (es: 'mensile', 'trimestrale', 'annuale')
  subscription_type text not null default 'mensile',
  
  -- Stato abbonamento
  status text not null default 'inactive' check (status in ('active', 'inactive', 'expired', 'cancelled')),
  
  -- Date validità
  start_date timestamptz,
  end_date timestamptz,
  
  -- Metadati
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  activated_by uuid references public.profiles(id) -- Admin che ha attivato
);

-- Indice unico parziale per garantire un solo abbonamento attivo per utente
create unique index if not exists idx_unique_active_subscription 
  on public.subscriptions(user_id) 
  where (status = 'active');

-- Indici per performance
create index if not exists idx_subscriptions_user_id on public.subscriptions(user_id);
create index if not exists idx_subscriptions_status on public.subscriptions(status);
create index if not exists idx_subscriptions_dates on public.subscriptions(start_date, end_date);

-- 2. TABELLA APPUNTAMENTI (SLOT)
-- ============================================
create table if not exists public.appointments (
  id uuid primary key default gen_random_uuid(),
  
  -- Data e ora appuntamento
  appointment_date date not null,
  appointment_time time not null,
  
  -- Durata in minuti
  duration_minutes int not null default 60,
  
  -- Posti disponibili
  max_participants int not null default 10,
  current_participants int not null default 0,
  
  -- Descrizione
  title text not null,
  description text,
  
  -- Creato da (admin)
  created_by uuid references public.profiles(id) not null,
  
  -- Metadati
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  
  -- Constraint: non più partecipanti dei posti disponibili
  constraint valid_participants check (current_participants <= max_participants)
);

-- Indici per performance
create index if not exists idx_appointments_date on public.appointments(appointment_date);
create index if not exists idx_appointments_datetime on public.appointments(appointment_date, appointment_time);

-- 3. TABELLA PRENOTAZIONI
-- ============================================
create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(),
  
  -- Riferimenti
  user_id uuid references public.profiles(id) on delete cascade not null,
  appointment_id uuid references public.appointments(id) on delete cascade not null,
  
  -- Stato prenotazione
  status text not null default 'confirmed' check (status in ('confirmed', 'cancelled', 'completed')),
  
  -- Metadati
  created_at timestamptz not null default timezone('utc', now()),
  cancelled_at timestamptz,
  
  -- Constraint: un utente non può prenotare lo stesso appuntamento due volte
  constraint unique_booking unique (user_id, appointment_id)
);

-- Indici per performance
create index if not exists idx_bookings_user_id on public.bookings(user_id);
create index if not exists idx_bookings_appointment_id on public.bookings(appointment_id);
create index if not exists idx_bookings_status on public.bookings(status);

-- 4. FUNZIONE: Conteggio appuntamenti settimanali per utente
-- ============================================
create or replace function public.count_weekly_bookings(p_user_id uuid, p_week_start date)
returns int
language sql
security definer
as $$
  select count(*)::int
  from public.bookings b
  join public.appointments a on a.id = b.appointment_id
  where b.user_id = p_user_id
    and b.status = 'confirmed'
    and a.appointment_date >= p_week_start
    and a.appointment_date < p_week_start + interval '7 days';
$$;

-- 5. FUNZIONE: Verifica se un utente può prenotare
-- ============================================
create or replace function public.can_user_book(p_user_id uuid, p_appointment_date date)
returns boolean
language plpgsql
security definer
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

-- 6. TRIGGER: Aggiorna contatore partecipanti
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
    set current_participants = current_participants + 1
    where id = NEW.appointment_id;
    
  elsif (TG_OP = 'UPDATE') then
    if (OLD.status = 'confirmed' and NEW.status != 'confirmed') then
      -- Decrementa partecipanti (cancellazione)
      update public.appointments
      set current_participants = current_participants - 1
      where id = NEW.appointment_id;
    elsif (OLD.status != 'confirmed' and NEW.status = 'confirmed') then
      -- Incrementa partecipanti (riconferma)
      update public.appointments
      set current_participants = current_participants + 1
      where id = NEW.appointment_id;
    end if;
    
  elsif (TG_OP = 'DELETE' and OLD.status = 'confirmed') then
    -- Decrementa partecipanti
    update public.appointments
    set current_participants = current_participants - 1
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

-- 7. ROW LEVEL SECURITY (RLS)
-- ============================================

-- Abilita RLS su tutte le tabelle
alter table public.subscriptions enable row level security;
alter table public.appointments enable row level security;
alter table public.bookings enable row level security;

-- SUBSCRIPTIONS: Policy
create policy "Users can view own subscription"
  on public.subscriptions for select
  using (auth.uid() = user_id);

create policy "Admins can manage all subscriptions"
  on public.subscriptions for all
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

-- APPOINTMENTS: Policy
create policy "Everyone can view appointments"
  on public.appointments for select
  to authenticated
  using (true);

create policy "Admins can manage appointments"
  on public.appointments for all
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

-- BOOKINGS: Policy
create policy "Users can view own bookings"
  on public.bookings for select
  using (auth.uid() = user_id);

create policy "Users can create own bookings"
  on public.bookings for insert
  to authenticated
  with check (
    auth.uid() = user_id
    and public.can_user_book(user_id, (
      select appointment_date from public.appointments where id = appointment_id
    ))
  );

create policy "Users can cancel own bookings"
  on public.bookings for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Admins can manage all bookings"
  on public.bookings for all
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

-- 8. VERIFICA FINALE
-- ============================================
select 'Schema appuntamenti creato con successo!' as status;

-- Mostra tabelle create
select table_name, table_type
from information_schema.tables
where table_schema = 'public'
  and table_name in ('subscriptions', 'appointments', 'bookings')
order by table_name;

