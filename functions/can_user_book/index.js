import { Client, Databases } from 'node-appwrite';

export default async ({ req, res }) => {
  const {
    APPWRITE_FUNCTION_PROJECT_ID,
    APPWRITE_FUNCTION_API_KEY,
    APPWRITE_FUNCTION_ENDPOINT,
    DATABASE_ID,
    BOOKINGS,
    APPOINTMENTS,
    SUBSCRIPTIONS,
  } = process.env;

  const client = new Client()
    .setEndpoint(APPWRITE_FUNCTION_ENDPOINT)
    .setProject(APPWRITE_FUNCTION_PROJECT_ID)
    .setKey(APPWRITE_FUNCTION_API_KEY);
  const db = new Databases(client);

  const userId = req.body?.userId;
  const appointmentDate = req.body?.appointmentDate; // ISO date string
  if (!userId || !appointmentDate) return res.json({ error: 'Parametri mancanti' }, 400);

  const now = new Date();

  // Abbonamento attivo
  const subs = await db.listDocuments(DATABASE_ID, SUBSCRIPTIONS, [
    `equal("user_id", ["${userId}"])`,
    `equal("status", ["active"])`,
  ]);
  const hasActive = subs.documents.some((s) => {
    const start = s.start_date ? new Date(s.start_date) : null;
    const end = s.end_date ? new Date(s.end_date) : null;
    return (!start || start <= now) && (!end || end >= now);
  });
  if (!hasActive) return res.json({ canBook: false });

  // Conta prenotazioni della settimana
  const start = new Date(appointmentDate);
  const day = start.getUTCDay() || 7; // 1-7
  start.setUTCDate(start.getUTCDate() - (day - 1)); // lunedì
  const end = new Date(start);
  end.setUTCDate(start.getUTCDate() + 7);

  const bookings = await db.listDocuments(DATABASE_ID, BOOKINGS, [
    `equal("user_id", ["${userId}"])`,
    `equal("status", ["confirmed"])`,
  ]);

  let count = 0;
  for (const b of bookings.documents) {
    const a = await db.getDocument(DATABASE_ID, APPOINTMENTS, b.appointment_id);
    const d = new Date(a.appointment_date);
    if (d >= start && d < end) count++;
  }

  return res.json({ canBook: count < 3, weeklyCount: count });
};

