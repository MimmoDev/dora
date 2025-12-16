-- ============================================
-- FIX: Constraint di unicità per le prenotazioni
-- Problema: Non si può riprenotare dopo aver cancellato
-- Soluzione: Il constraint considera solo prenotazioni confermate
-- ============================================

-- 1. Rimuovi il vecchio constraint
alter table public.bookings 
drop constraint if exists unique_booking;

-- 2. Crea un indice parziale che considera solo prenotazioni confermate
-- Questo permette di avere prenotazioni cancellate per lo stesso user_id/appointment_id
create unique index unique_active_booking 
on public.bookings (user_id, appointment_id)
where status = 'confirmed';

-- ============================================
-- VERIFICA
-- ============================================

-- Mostra gli indici sulla tabella bookings
select 
    indexname,
    indexdef
from pg_indexes
where tablename = 'bookings'
  and schemaname = 'public'
  and indexname like '%unique%';

-- Test: Mostra le prenotazioni duplicate (dovrebbe essere vuoto)
select 
    user_id,
    appointment_id,
    status,
    count(*) as count
from public.bookings
where status = 'confirmed'
group by user_id, appointment_id, status
having count(*) > 1;

-- ============================================
-- RISULTATO ATTESO:
-- ============================================
-- ✅ Vecchio constraint rimosso
-- ✅ Nuovo indice parziale creato
-- ✅ Ora puoi:
--    - Cancellare una prenotazione
--    - Riprenotare lo stesso appuntamento
--    - Avere più record cancellati per lo stesso appuntamento
-- ✅ Ma NON puoi:
--    - Avere 2+ prenotazioni CONFERMATE per lo stesso user/appointment




