-- ============================================
-- RENDI UN UTENTE AMMINISTRATORE
-- ============================================

-- STEP 1: Trova l'utente che vuoi rendere admin
-- Esegui questa query per vedere tutti gli utenti:
select 
    id,
    email,
    created_at
from auth.users
order by created_at desc;

-- STEP 2: Copia l'ID dell'utente che vuoi rendere admin
-- e aggiorna il profilo con il ruolo 'admin'

-- ESEMPIO (sostituisci con l'ID reale):
-- update public.profiles
-- set role = 'admin'
-- where id = 'INCOLLA_QUI_L_ID_UTENTE';

-- STEP 3: Verifica che l'utente sia ora admin
-- select 
--     id,
--     first_name,
--     last_name,
--     role
-- from public.profiles
-- where role = 'admin';

-- ============================================
-- SCRIPT RAPIDO (se conosci già l'email)
-- ============================================
-- Questo script rende admin un utente cercandolo per email

-- Sostituisci 'admin@esempio.com' con l'email dell'utente
do $$
declare
    user_id uuid;
begin
    -- Cerca l'ID dell'utente dall'email
    select id into user_id
    from auth.users
    where email = 'admin@esempio.com'; -- CAMBIA QUESTA EMAIL
    
    if user_id is null then
        raise exception 'Utente non trovato con questa email';
    end if;
    
    -- Aggiorna il ruolo a 'admin'
    update public.profiles
    set role = 'admin'
    where id = user_id;
    
    raise notice 'Utente % è ora amministratore', user_id;
end $$;

-- ============================================
-- RIMUOVERE I PRIVILEGI ADMIN
-- ============================================
-- Per tornare un utente a ruolo normale:

-- update public.profiles
-- set role = 'user'
-- where id = 'ID_UTENTE_QUI';

-- ============================================
-- VERIFICA FINALE
-- ============================================
select 
    p.id,
    u.email,
    p.first_name,
    p.last_name,
    p.role,
    case 
        when p.role = 'admin' then '✅ ADMIN'
        else '👤 USER'
    end as status
from public.profiles p
join auth.users u on u.id = p.id
where p.role = 'admin'
order by p.created_at desc;




