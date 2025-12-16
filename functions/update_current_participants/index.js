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

  const appointmentId = req.body?.appointmentId;
  if (!appointmentId) return res.json({ error: 'appointmentId mancante' }, 400);

  const bookings = await db.listDocuments(DATABASE_ID, BOOKINGS, [
    `equal("appointment_id", ["${appointmentId}"])`,
    `equal("status", ["confirmed"])`,
  ]);
  const count = bookings.total;

  await db.updateDocument(DATABASE_ID, APPOINTMENTS, appointmentId, {
    current_participants: count,
    updated_at: new Date().toISOString(),
  });

  return res.json({ updated: true, current_participants: count });
};

