import { Client, Databases } from 'node-appwrite';

export default async ({ req, res }) => {
  const {
    APPWRITE_FUNCTION_PROJECT_ID,
    APPWRITE_FUNCTION_API_KEY,
    APPWRITE_FUNCTION_ENDPOINT,
    DATABASE_ID,
    BOOKINGS,
    APPOINTMENTS,
  } = process.env;

  const client = new Client()
    .setEndpoint(APPWRITE_FUNCTION_ENDPOINT)
    .setProject(APPWRITE_FUNCTION_PROJECT_ID)
    .setKey(APPWRITE_FUNCTION_API_KEY);
  const db = new Databases(client);

  const userId = req.body?.userId;
  const weekStart = req.body?.weekStart; // ISO date (yyyy-mm-dd)
  if (!userId || !weekStart) return res.json({ error: 'Parametri mancanti' }, 400);

  const start = new Date(weekStart);
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

  return res.json({ count });
};

