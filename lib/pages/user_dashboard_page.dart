import 'package:flutter/material.dart';

import '../models/appointment.dart';
import '../models/booking.dart';
import '../repositories/appointment_repository.dart';
import '../repositories/auth_repository.dart';
import '../repositories/booking_repository.dart';
import '../repositories/subscription_repository.dart';
import 'qr_scanner_page.dart';

class UserDashboardPage extends StatefulWidget {
  const UserDashboardPage({super.key});

  @override
  State<UserDashboardPage> createState() => _UserDashboardPageState();
}

class _UserDashboardPageState extends State<UserDashboardPage> {
  final _appointmentRepo = AppointmentRepository();
  final _bookingRepo = BookingRepository();
  final _subscriptionRepo = SubscriptionRepository();
  final _authRepo = AuthRepository();

  late final String _userId;
  DateTime _selectedWeekStart = _getWeekStart(DateTime.now());

  @override
  void initState() {
    super.initState();
    _userId = _authRepo.currentUser?.id ?? '';
  }

  static DateTime _getWeekStart(DateTime date) {
    // Ottieni il lunedì della settimana corrente
    final weekday = date.weekday;
    return DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: weekday - 1));
  }

  void _previousWeek() {
    setState(() {
      _selectedWeekStart = _selectedWeekStart.subtract(const Duration(days: 7));
    });
  }

  void _nextWeek() {
    setState(() {
      _selectedWeekStart = _selectedWeekStart.add(const Duration(days: 7));
    });
  }

  void _goToCurrentWeek() {
    setState(() {
      _selectedWeekStart = _getWeekStart(DateTime.now());
    });
  }

  String _formatWeekRange() {
    final end = _selectedWeekStart.add(const Duration(days: 6));
    return '${_selectedWeekStart.day}/${_selectedWeekStart.month} - ${end.day}/${end.month}/${end.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Header con selettore settimana
          _buildWeekSelector(),
          
          // Lista appuntamenti
          Expanded(
            child: _buildAppointmentsList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const QRScannerPage(),
            ),
          );
        },
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Timbra'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildWeekSelector() {
    final isCurrentWeek = _selectedWeekStart.isAtSameMomentAs(_getWeekStart(DateTime.now()));
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _previousWeek,
                  icon: const Icon(Icons.chevron_left, color: Colors.white),
                ),
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'Settimana',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        _formatWeekRange(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _nextWeek,
                  icon: const Icon(Icons.chevron_right, color: Colors.white),
                ),
              ],
            ),
            if (!isCurrentWeek) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _goToCurrentWeek,
                icon: const Icon(Icons.today, color: Colors.white, size: 16),
                label: const Text(
                  'Vai alla settimana corrente',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }


  Widget _buildAppointmentsList() {
    return FutureBuilder<List<Appointment>>(
      future: _appointmentRepo.getAppointmentsForWeek(_selectedWeekStart),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Errore: ${snapshot.error}'),
          );
        }

        final appointments = snapshot.data ?? [];

        if (appointments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_busy,
                  size: 64,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'Nessun appuntamento disponibile\nper questa settimana',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: appointments.length,
          itemBuilder: (context, index) {
            return _AppointmentCard(
              appointment: appointments[index],
              userId: _userId,
              bookingRepo: _bookingRepo,
              subscriptionRepo: _subscriptionRepo,
              weekStart: _selectedWeekStart,
              onBookingChanged: () {
                setState(() {}); // Refresh
              },
            );
          },
        );
      },
    );
  }
}

class _AppointmentCard extends StatefulWidget {
  const _AppointmentCard({
    required this.appointment,
    required this.userId,
    required this.bookingRepo,
    required this.subscriptionRepo,
    required this.weekStart,
    required this.onBookingChanged,
  });

  final Appointment appointment;
  final String userId;
  final BookingRepository bookingRepo;
  final SubscriptionRepository subscriptionRepo;
  final DateTime weekStart;
  final VoidCallback onBookingChanged;

  @override
  State<_AppointmentCard> createState() => _AppointmentCardState();
}

class _AppointmentCardState extends State<_AppointmentCard> {
  bool _isLoading = false;
  Booking? _userBooking;

  @override
  void initState() {
    super.initState();
    _checkUserBooking();
  }

  Future<void> _checkUserBooking() async {
    try {
      final booking = await widget.bookingRepo.getUserBookingForAppointment(
        widget.userId,
        widget.appointment.id,
      );
      if (mounted) {
        setState(() {
          _userBooking = booking;
        });
      }
    } catch (e) {
      debugPrint('Error checking booking: $e');
    }
  }

  Future<void> _handleBooking() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      if (_userBooking != null) {
        // Cancella prenotazione
        await widget.bookingRepo.cancelBooking(_userBooking!.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Prenotazione cancellata')),
          );
          setState(() {
            _userBooking = null;
          });
          widget.onBookingChanged();
        }
      } else {
        // Verifica se può prenotare
        final canBook = await widget.bookingRepo.canUserBook(
          widget.userId,
          widget.appointment.appointmentDate,
        );

        if (!canBook) {
          if (mounted) {
            // Verifica il motivo specifico
            final hasSubscription = await widget.subscriptionRepo
                .hasActiveSubscription(widget.userId);
            
            String message;
            if (!hasSubscription) {
              message = '❌ Abbonamento non attivo\n\nContatta l\'amministratore per attivare il tuo abbonamento.';
            } else {
              message = '⚠️ Limite settimanale raggiunto!\n\nHai già prenotato 3 appuntamenti questa settimana.\nRiprova la prossima settimana.';
            }
            
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Row(
                  children: [
                    Icon(
                      hasSubscription ? Icons.warning : Icons.error,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 8),
                    const Text('Impossibile prenotare'),
                  ],
                ),
                content: Text(message),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
          setState(() => _isLoading = false);
          return;
        }

        // Crea prenotazione
        final booking = await widget.bookingRepo.createBooking(
          userId: widget.userId,
          appointmentId: widget.appointment.id,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Prenotazione confermata!')),
          );
          setState(() {
            _userBooking = booking;
          });
          widget.onBookingChanged();
        }
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
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBooked = _userBooking != null;
    final isFull = widget.appointment.isFull;
    final fillPercentage = widget.appointment.currentParticipants /
        widget.appointment.maxParticipants;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isBooked
            ? BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              )
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Data e ora
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDate(widget.appointment.appointmentDate),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  widget.appointment.appointmentTime,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Titolo
            Text(
              widget.appointment.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            if (widget.appointment.description != null) ...[
              const SizedBox(height: 8),
              Text(
                widget.appointment.description!,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Barra posti disponibili
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Posti occupati',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      '${widget.appointment.currentParticipants}/${widget.appointment.maxParticipants}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isFull ? Colors.red : Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fillPercentage,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      fillPercentage >= 0.9
                          ? Colors.red
                          : fillPercentage >= 0.7
                              ? Colors.orange
                              : Colors.green,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Bottone prenota/cancella
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: (isFull && !isBooked) || _isLoading
                    ? null
                    : _handleBooking,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(isBooked ? Icons.close : Icons.check),
                label: Text(
                  _isLoading
                      ? 'Attendere...'
                      : isBooked
                          ? 'Cancella prenotazione'
                          : isFull
                              ? 'Esaurito'
                              : 'Prenota',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: isBooked
                      ? Colors.red
                      : isFull
                          ? Colors.grey
                          : Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            
            if (isBooked)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Sei prenotato a questo appuntamento',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final weekdays = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];
    final weekday = weekdays[date.weekday - 1];
    return '$weekday ${date.day}/${date.month}';
  }
}

