# 🎫 Generare QR Code per la Palestra

## Password QR Code Attuale
```
DORA2025GYM
```

## Come Generare il QR Code

### Opzione 1: Online (Più Veloce)
1. Vai su [https://www.qr-code-generator.com/](https://www.qr-code-generator.com/)
2. Seleziona "Text"
3. Inserisci: `DORA2025GYM`
4. Scarica il QR code in alta risoluzione
5. Stampalo in formato A4

### Opzione 2: Con Python
```python
import qrcode

# Crea il QR code
qr = qrcode.QRCode(
    version=1,
    error_correction=qrcode.constants.ERROR_CORRECT_L,
    box_size=10,
    border=4,
)
qr.add_data('DORA2025GYM')
qr.make(fit=True)

# Salva l'immagine
img = qr.make_image(fill_color="black", back_color="white")
img.save("dora_gym_qr.png")
```

### Opzione 3: Con Node.js
```javascript
const QRCode = require('qrcode');

QRCode.toFile('dora_gym_qr.png', 'DORA2025GYM', {
  width: 500,
  margin: 2,
}, function (err) {
  if (err) throw err;
  console.log('QR code saved!');
});
```

## 📋 Dove Posizionare il QR Code

1. **All'ingresso della palestra** - Vicino alla reception
2. **In sala attrezzi** - Ben visibile
3. **Nell'area corsi** - Per le lezioni di gruppo

## 🔐 Cambiare la Password

Se vuoi cambiare la password del QR code:

```sql
update public.gym_settings
set setting_value = 'NUOVA_PASSWORD_QUI',
    updated_at = now()
where setting_key = 'qr_code_password';
```

Poi genera un nuovo QR code con la nuova password!

## ✅ Testing

Per testare il sistema:

1. Esegui `check_in_schema.sql` in Supabase
2. Genera il QR code con la password `DORA2025GYM`
3. Apri l'app e premi "Timbra"
4. Scansiona il QR code
5. Verifica il risultato!

## 📊 Regole Check-in

| Situazione | Risultato |
|------------|-----------|
| ✅ QR valido + prenotazione oggi + orario corretto (30 min prima - 15 min dopo) | Check-in OK |
| ❌ QR invalido | Errore QR |
| ❌ Nessuna prenotazione per oggi | Nessuna prenotazione |
| ⏰ Troppo presto (>30 min prima) | Troppo presto |
| ⏰ Troppo tardi (>15 min dopo inizio) | In ritardo |

## 🎨 Personalizzazione QR

Per un QR più bello, aggiungi:
- **Logo della palestra** al centro
- **Colori aziendali**
- **Testo informativo** sotto il QR ("Scansiona per timbrare")




