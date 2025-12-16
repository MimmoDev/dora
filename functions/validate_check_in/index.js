import { Client, Databases } from 'node-appwrite';

export default async ({ req, res }) => {
  const {
    APPWRITE_FUNCTION_PROJECT_ID,
    APPWRITE_FUNCTION_API_KEY,
    APPWRITE_FUNCTION_ENDPOINT,
    DATABASE_ID,
    BOOKINGS,
    APPOINTMENTS,
    GYM_SETTINGS,
  } = process.env;

  const client = new Client()
    .setEndpoint(APPWRITE_FUNCTION_ENDPOINT)
    .setProject(APPWRITE_FUNCTION_PROJECT_ID)
    .setKey(APPWRITE_FUNCTION_API_KEY);
  const db = new Databases(client);

  const userId = req.body?.userId;
  const qrPassword = req.body?.qrPassword;
  if (!userId || !qrPassword) {
    return res.json({ valid: false, status: 'invalid_qr', message: 'Parametri mancanti' }, 400);
  }

  const getSetting = async (key, fallback) => {
    const r = await db.listDocuments(DATABASE_ID, GYM_SETTINGS, [`equal("setting_key", ["${key}"])`]);
    return r.total ? r.documents[0].setting_value : fallback;
  };

  const correct = await getSetting('qr_code_password', null);
  if (!correct || qrPassword !== correct) {
    return res.json({ valid: false, status: 'invalid_qr', message: 'QR Code non valido' });
  }

  const early = parseInt(await getSetting('check_in_early_minutes', '30'), 10);
  const late = parseInt(await getSetting('check_in_late_minutes', '15'), 10);

  const todayIso = new Date().toISOString().substring(0, 10);

  const bookings = await db.listDocuments(DATABASE_ID, BOOKINGS, [
    `equal("user_id", ["${userId}"])`,
    `equal("status", ["confirmed"])`,
  ]);

  let target = null;
  for (const b of bookings.documents) {
    const a = await db.getDocument(DATABASE_ID, APPOINTMENTS, b.appointment_id);
    if (a.appointment_date.substring(0, 10) === todayIso) {
      target = { b, a };
      break;
    }
  }

  if (!target) {
    return res.json({ valid: false, status: 'no_booking', message: 'Non hai prenotazioni per oggi' });
  }

  const [hh, mm] = target.a.appointment_time.split(':').map(Number);
  const apptDate = new Date(target.a.appointment_date);
  apptDate.setUTCHours(hh, mm, 0, 0);
  const diffMin = (Date.now() - apptDate.getTime()) / 60000;

  if (diffMin < -early) {
    return res.json({
      valid: false,
      status: 'early',
      message: `Sei troppo in anticipo. Puoi timbrare ${early} minuti prima.`,
      booking_id: target.b.$id,
      appointment_id: target.a.$id,
      appointment_time: target.a.appointment_time,
      appointment_title: target.a.title,
    });
  }

  if (diffMin > late) {
    return res.json({
      valid: false,
      status: 'late',
      message: `Sei in ritardo. Puoi timbrare fino a ${late} minuti dopo l'inizio.`,
      booking_id: target.b.$id,
      appointment_id: target.a.$id,
      appointment_time: target.a.appointment_time,
      appointment_title: target.a.title,
    });
  }

  return res.json({
    valid: true,
    status: 'valid',
    message: 'Check-in effettuato con successo!',
    booking_id: target.b.$id,
    appointment_id: target.a.$id,
    appointment_time: target.a.appointment_time,
    appointment_title: target.a.title,
    appointment_description: target.a.description,
  });
};

