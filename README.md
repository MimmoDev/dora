# dora_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

## Appwrite Functions (Node 20)

Cartella `functions/` con gli entrypoint:
- `validate_check_in`
- `count_weekly_bookings`
- `can_user_book`
- `update_current_participants`

Variabili da impostare per ogni Function:
- `DATABASE_ID=dora`
- `BOOKINGS=bookings`
- `APPOINTMENTS=appointments`
- `GYM_SETTINGS=gym_settings`
- `SUBSCRIPTIONS=subscriptions` (solo per can_user_book)

Permessi di esecuzione consigliati:
- `validate_check_in`, `count_weekly_bookings`, `can_user_book`: `users` (JWT sessione).
- `update_current_participants`: `team:6941972100137c456711` (admin) o `users` se richiamata dal client.

Deployment rapido da console Appwrite:
1. Crea Function (Runtime Node 20), incolla `index.js`.
2. Imposta le Environment variables sopra.
3. Concedi le permissions di esecuzione.
4. Deploy (tag/versione).
