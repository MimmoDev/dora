import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/appointment.dart';
import '../../repositories/booking_repository.dart';

class AppointmentParticipantsPage extends StatefulWidget {
  const AppointmentParticipantsPage({
    super.key,
    required this.appointment,
  });

  final Appointment appointment;

  @override
  State<AppointmentParticipantsPage> createState() =>
      _AppointmentParticipantsPageState();
}

class _AppointmentParticipantsPageState
    extends State<AppointmentParticipantsPage> {
  final _bookingRepo = BookingRepository();
  
  List<Map<String, dynamic>> _participants = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadParticipants();
  }

  Future<void> _loadParticipants() async {
    setState(() => _isLoading = true);
    try {
      final participants =
          await _bookingRepo.getAppointmentBookings(widget.appointment.id);

      if (mounted) {
        setState(() {
          _participants = participants;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cancelBooking(String bookingId, String userName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma cancellazione'),
        content: Text(
          'Sei sicuro di voler cancellare la prenotazione di $userName?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Cancella'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _bookingRepo.cancelBooking(bookingId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Prenotazione cancellata'),
            backgroundColor: Colors.green,
          ),
        );
        _loadParticipants();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFull = widget.appointment.isFull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Partecipanti'),
        actions: [
          IconButton(
            onPressed: _loadParticipants,
            icon: const Icon(Icons.refresh),
            tooltip: 'Ricarica',
          ),
        ],
      ),
      body: Column(
        children: [
          // Appointment Info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.appointment.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(widget.appointment.appointmentDate),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Icon(
                      Icons.access_time,
                      size: 16,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.appointment.appointmentTime,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Posti occupati',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      '${widget.appointment.currentParticipants}/${widget.appointment.maxParticipants}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isFull ? Colors.red.shade300 : Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: widget.appointment.currentParticipants /
                        widget.appointment.maxParticipants,
                    minHeight: 8,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isFull ? Colors.red.shade300 : Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Participants List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _participants.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 64,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Nessun partecipante ancora',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _participants.length,
                        itemBuilder: (context, index) {
                          final participant = _participants[index];
                          return _ParticipantCard(
                            participant: participant,
                            onCancel: () {
                              final profile = participant['profiles']
                                  as Map<String, dynamic>?;
                              final userName = profile != null
                                  ? '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}'
                                      .trim()
                                  : 'Utente';
                              _cancelBooking(
                                participant['id'] as String,
                                userName,
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }
}

class _ParticipantCard extends StatelessWidget {
  const _ParticipantCard({
    required this.participant,
    required this.onCancel,
  });

  final Map<String, dynamic> participant;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final profile = participant['profiles'] as Map<String, dynamic>?;
    final createdAt = DateTime.parse(participant['created_at'] as String);
    
    final firstName = profile?['first_name'] as String? ?? '';
    final lastName = profile?['last_name'] as String? ?? '';
    final phone = profile?['phone'] as String?;
    
    final userName = '$firstName $lastName'.trim();
    final initials = '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'
        .toUpperCase();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Text(
            initials,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          userName.isEmpty ? 'Utente sconosciuto' : userName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (phone != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.phone, size: 14),
                  const SizedBox(width: 4),
                  Text(phone),
                ],
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.access_time, size: 14),
                const SizedBox(width: 4),
                Text(
                  'Prenotato: ${DateFormat('dd/MM/yyyy HH:mm').format(createdAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          onPressed: onCancel,
          icon: const Icon(Icons.cancel, color: Colors.red),
          tooltip: 'Cancella prenotazione',
        ),
      ),
    );
  }
}




