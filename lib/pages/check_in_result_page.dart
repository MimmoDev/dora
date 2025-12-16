import 'package:flutter/material.dart';

class CheckInResultPage extends StatelessWidget {
  const CheckInResultPage({
    super.key,
    required this.result,
  });

  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final isValid = result['valid'] as bool;
    final status = result['status'] as String;
    final message = result['message'] as String;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Risultato Check-in'),
        backgroundColor: isValid
            ? Colors.green
            : Colors.red,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icona risultato
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: isValid
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getIcon(status),
                  size: 64,
                  color: isValid ? Colors.green : Colors.red,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Titolo
              Text(
                isValid ? 'Check-in confermato!' : 'Check-in non valido',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isValid ? Colors.green : Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              // Messaggio
              Text(
                message,
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              
              if (isValid && result.containsKey('appointment_title')) ...[
                const SizedBox(height: 32),
                
                // Info appuntamento
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.green.shade200,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.event_available,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  result['appointment_title'] as String,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (result.containsKey('appointment_description') &&
                                    result['appointment_description'] != null)
                                  Text(
                                    result['appointment_description'] as String,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            color: Colors.green,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Orario: ${result['appointment_time']}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              
              if (!isValid && result.containsKey('appointment_title')) ...[
                const SizedBox(height: 24),
                
                // Info appuntamento per errore
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.red.shade200,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'La tua prenotazione:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        result['appointment_title'] as String,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Orario: ${result['appointment_time']}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 48),
              
              // Bottone torna alla home
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  icon: const Icon(Icons.home),
                  label: const Text('Torna alla Home'),
                  style: FilledButton.styleFrom(
                    backgroundColor: isValid
                        ? Colors.green
                        : Theme.of(context).colorScheme.primary,
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIcon(String status) {
    switch (status) {
      case 'valid':
        return Icons.check_circle;
      case 'late':
        return Icons.schedule;
      case 'early':
        return Icons.watch_later;
      case 'no_booking':
        return Icons.event_busy;
      case 'invalid_qr':
        return Icons.qr_code_scanner;
      default:
        return Icons.error;
    }
  }
}




