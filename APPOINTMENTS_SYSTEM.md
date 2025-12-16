# 📅 Sistema Appuntamenti - Documentazione

## 🗄️ Struttura Database

### Tabelle Create

#### 1. **subscriptions** (Abbonamenti)
Gestisce gli abbonamenti degli utenti.

**Campi principali:**
- `user_id` - Riferimento al profilo utente
- `subscription_type` - Tipo abbonamento (mensile, trimestrale, annuale)
- `status` - Stato: `active`, `inactive`, `expired`, `cancelled`
- `start_date` / `end_date` - Date di validità
- `activated_by` - Admin che ha attivato l'abbonamento

**Vincoli:**
- Un utente può avere un solo abbonamento attivo alla volta

#### 2. **appointments** (Appuntamenti/Slot)
Gli slot disponibili per le prenotazioni.

**Campi principali:**
- `appointment_date` - Data appuntamento
- `appointment_time` - Ora appuntamento
- `duration_minutes` - Durata (default: 60 minuti)
- `max_participants` - Posti totali (default: 10)
- `current_participants` - Posti occupati (auto-aggiornato)
- `title` / `description` - Info appuntamento
- `created_by` - Admin che ha creato lo slot

**Vincoli:**
- `current_participants` non può superare `max_participants`

#### 3. **bookings** (Prenotazioni)
Le prenotazioni degli utenti agli appuntamenti.

**Campi principali:**
- `user_id` - Utente che prenota
- `appointment_id` - Appuntamento prenotato
- `status` - Stato: `confirmed`, `cancelled`, `completed`
- `cancelled_at` - Data cancellazione (se applicabile)

**Vincoli:**
- Un utente non può prenotare lo stesso appuntamento due volte

---

## 🔐 Regole Business

### ✅ Requisiti per Prenotare

Per prenotare un appuntamento, l'utente DEVE:

1. **Avere un abbonamento attivo**
   - Status = `active`
   - `start_date` <= oggi
   - `end_date` >= oggi (o null)

2. **Rispettare il limite settimanale**
   - Max 3 appuntamenti per settimana
   - La settimana parte da lunedì

3. **Verificare disponibilità**
   - Lo slot non deve essere pieno
   - `current_participants` < `max_participants`

---

## 🛠️ Funzioni SQL Utili

### `can_user_book(user_id, appointment_date)`
Verifica se un utente può prenotare un appuntamento.

**Controlla:**
- ✅ Abbonamento attivo
- ✅ Limite settimanale (3 max)

**Uso:**
```sql
select public.can_user_book('user-uuid', '2025-11-15');
```

### `count_weekly_bookings(user_id, week_start)`
Conta le prenotazioni confermate di un utente in una settimana.

**Uso:**
```sql
select public.count_weekly_bookings('user-uuid', '2025-11-11');
```

---

## 🔒 Row Level Security (RLS)

### Subscriptions
- 👤 **Utenti**: possono vedere solo il proprio abbonamento
- 👨‍💼 **Admin**: possono gestire tutti gli abbonamenti

### Appointments
- 👥 **Tutti gli autenticati**: possono vedere tutti gli appuntamenti
- 👨‍💼 **Admin**: possono creare/modificare/eliminare

### Bookings
- 👤 **Utenti**: possono vedere/creare/cancellare le proprie prenotazioni
- 🚫 La creazione è bloccata automaticamente se:
  - Non hanno abbonamento attivo
  - Hanno già 3 prenotazioni nella settimana
- 👨‍💼 **Admin**: possono gestire tutte le prenotazioni

---

## 🤖 Trigger Automatici

### Update Participants Count
Quando una prenotazione viene:
- ✅ **Creata** (status=confirmed) → `current_participants + 1`
- ❌ **Cancellata** (status→cancelled) → `current_participants - 1`
- 🔄 **Modificata** → aggiorna di conseguenza

Questo mantiene sempre sincronizzato il contatore dei partecipanti!

---

## 📊 Modelli Dart Creati

### 1. `Subscription` (`lib/models/subscription.dart`)
```dart
final subscription = Subscription(
  id: 'uuid',
  userId: 'user-uuid',
  subscriptionType: 'mensile',
  status: 'active',
  startDate: DateTime.now(),
  endDate: DateTime.now().add(Duration(days: 30)),
  createdAt: DateTime.now(),
);

// Helper
subscription.isActive; // true/false
```

### 2. `Appointment` (`lib/models/appointment.dart`)
```dart
final appointment = Appointment(
  id: 'uuid',
  appointmentDate: DateTime(2025, 11, 15),
  appointmentTime: '10:00',
  durationMinutes: 60,
  maxParticipants: 10,
  currentParticipants: 5,
  title: 'Lezione Yoga',
  description: 'Lezione per principianti',
  createdBy: 'admin-uuid',
  createdAt: DateTime.now(),
);

// Helpers
appointment.isFull; // false
appointment.hasAvailableSpots; // true
appointment.availableSpots; // 5
appointment.fullDateTime; // DateTime completo
```

### 3. `Booking` (`lib/models/booking.dart`)
```dart
final booking = Booking(
  id: 'uuid',
  userId: 'user-uuid',
  appointmentId: 'appointment-uuid',
  status: 'confirmed',
  createdAt: DateTime.now(),
);

// Helpers
booking.isConfirmed; // true
booking.isCancelled; // false
booking.isCompleted; // false
```

---

## 🚀 Prossimi Passi

### 1. Esegui lo schema SQL
```bash
# In Supabase SQL Editor, esegui:
appointments_schema.sql
```

### 2. Crea i Repository
- `AppointmentRepository` - CRUD appuntamenti
- `BookingRepository` - Gestione prenotazioni
- `SubscriptionRepository` - Gestione abbonamenti

### 3. Implementa le UI
- Lista appuntamenti disponibili
- Calendario prenotazioni
- Riepilogo prenotazioni utente
- Badge "3/3" prenotazioni settimanali
- Admin panel per:
  - Creare appuntamenti
  - Attivare abbonamenti
  - Gestire prenotazioni

### 4. Features Extra
- Notifiche prima dell'appuntamento
- Cancellazione entro X ore
- Lista d'attesa per appuntamenti pieni
- Statistiche per admin

---

## 💡 Note Tecniche

### Calcolo Settimana
La funzione `count_weekly_bookings` usa il lunedì come inizio settimana:
```sql
date_trunc('week', date)::date
```

### Gestione Timezone
Tutte le date sono salvate in UTC:
```sql
timezone('utc', now())
```

### Performance
Indici creati su:
- `user_id` (tutte le tabelle)
- `appointment_date` + `appointment_time`
- `status` (subscriptions e bookings)

---

## ❓ FAQ

**Q: Cosa succede se un utente prenota e poi l'abbonamento scade?**
A: La prenotazione rimane valida (status=confirmed), ma non potrà fare nuove prenotazioni.

**Q: Un admin può prenotare oltre il limite?**
A: No, le regole valgono per tutti. Se serve, l'admin può modificare direttamente il DB.

**Q: Come gestire le cancellazioni last-minute?**
A: Puoi aggiungere un campo `cancellation_deadline_hours` nella tabella appointments.

**Q: Come implementare una lista d'attesa?**
A: Aggiungi una tabella `waiting_list` con riferimenti a user + appointment.




