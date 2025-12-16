import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/profile.dart';
import '../models/subscription.dart';
import '../models/check_in.dart';
import '../models/booking.dart';
import '../repositories/profile_repository.dart';
import '../repositories/subscription_repository.dart';
import '../repositories/check_in_repository.dart';
import '../repositories/booking_repository.dart';
import '../repositories/auth_repository.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage>
    with SingleTickerProviderStateMixin {
  final _profileRepo = ProfileRepository();
  final _subscriptionRepo = SubscriptionRepository();
  final _checkInRepo = CheckInRepository();
  final _bookingRepo = BookingRepository();
  final _authRepo = AuthRepository();

  late final String _userId;
  late TabController _tabController;

  Profile? _profile;
  Subscription? _subscription;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _userId = _authRepo.currentUser?.id ?? '';
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final profile = await _profileRepo.fetchProfile(_userId);
      final subscription = await _subscriptionRepo.getActiveSubscription(_userId);

      if (mounted) {
        setState(() {
          _profile = profile;
          _subscription = subscription;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore nel caricamento: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Il Mio Profilo'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadData();
            },
            tooltip: 'Ricarica',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header profilo con info abbonamento
                _buildProfileHeader(),

                // Tabs
                Container(
                  color: Theme.of(context).colorScheme.primary,
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.white,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.qr_code_scanner),
                        text: 'Check-in',
                      ),
                      Tab(
                        icon: Icon(Icons.event),
                        text: 'Lezioni',
                      ),
                    ],
                  ),
                ),

                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _CheckInHistoryTab(
                        userId: _userId,
                        checkInRepo: _checkInRepo,
                      ),
                      _BookingHistoryTab(
                        userId: _userId,
                        bookingRepo: _bookingRepo,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildProfileHeader() {
    final hasActiveSubscription = _subscription?.isActive ?? false;
    final daysUntilExpiry = _subscription?.daysUntilExpiry;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
        children: [
          // Avatar e nome
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.white,
            child: Text(
              _getInitials(),
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${_profile?.firstName ?? ''} ${_profile?.lastName ?? ''}'.trim(),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          if (_profile?.phone != null) ...[
            const SizedBox(height: 4),
            Text(
              _profile!.phone!,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Card abbonamento
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      hasActiveSubscription
                          ? Icons.check_circle
                          : Icons.cancel,
                      color: hasActiveSubscription ? Colors.green : Colors.red,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasActiveSubscription
                                ? 'Abbonamento Attivo'
                                : 'Nessun Abbonamento',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_subscription != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              _getSubscriptionTypeLabel(_subscription!.type),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (_subscription != null && hasActiveSubscription) ...[
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Scadenza',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _subscription!.endDate != null
                                ? _formatDate(_subscription!.endDate!)
                                : 'Non definita',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if (daysUntilExpiry != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getExpiryColor(daysUntilExpiry),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            daysUntilExpiry > 0
                                ? '$daysUntilExpiry giorni'
                                : 'Scaduto',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                if (!hasActiveSubscription)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Contatta l\'amministratore per attivare\nil tuo abbonamento',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials() {
    final firstName = _profile?.firstName ?? '';
    final lastName = _profile?.lastName ?? '';
    return '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'
        .toUpperCase();
  }

  String _getSubscriptionTypeLabel(String type) {
    switch (type) {
      case 'monthly':
        return 'Mensile';
      case 'quarterly':
        return 'Trimestrale';
      case 'annual':
        return 'Annuale';
      default:
        return type;
    }
  }

  Color _getExpiryColor(int daysUntilExpiry) {
    if (daysUntilExpiry <= 0) return Colors.red;
    if (daysUntilExpiry <= 7) return Colors.orange;
    if (daysUntilExpiry <= 30) return Colors.yellow.shade700;
    return Colors.green;
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }
}

// ============================================
// TAB: Storico Check-in
// ============================================
class _CheckInHistoryTab extends StatelessWidget {
  const _CheckInHistoryTab({
    required this.userId,
    required this.checkInRepo,
  });

  final String userId;
  final CheckInRepository checkInRepo;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CheckIn>>(
      future: checkInRepo.getUserCheckIns(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Errore nel caricamento\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final checkIns = snapshot.data ?? [];

        if (checkIns.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.qr_code_scanner,
                  size: 64,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'Nessun check-in ancora',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Scansiona il QR code in palestra\nper registrare la tua presenza',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: checkIns.length,
          itemBuilder: (context, index) {
            final checkIn = checkIns[index];
            return _CheckInCard(checkIn: checkIn);
          },
        );
      },
    );
  }
}

class _CheckInCard extends StatelessWidget {
  const _CheckInCard({required this.checkIn});

  final CheckIn checkIn;

  @override
  Widget build(BuildContext context) {
    final isValid = checkIn.status == 'valid';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(checkIn.status).withOpacity(0.2),
          child: Icon(
            _getStatusIcon(checkIn.status),
            color: _getStatusColor(checkIn.status),
          ),
        ),
        title: Text(
          _formatDateTime(checkIn.checkedInAt),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(_getStatusLabel(checkIn.status)),
        trailing: isValid
            ? const Icon(Icons.check_circle, color: Colors.green)
            : const Icon(Icons.info_outline, color: Colors.orange),
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'valid':
        return Icons.check_circle;
      case 'late':
        return Icons.schedule;
      case 'early':
        return Icons.access_time;
      case 'no_booking':
        return Icons.event_busy;
      default:
        return Icons.info;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'valid':
        return Colors.green;
      case 'late':
      case 'early':
        return Colors.orange;
      case 'no_booking':
      case 'invalid_qr':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'valid':
        return 'Check-in valido';
      case 'late':
        return 'In ritardo';
      case 'early':
        return 'Troppo in anticipo';
      case 'no_booking':
        return 'Nessuna prenotazione';
      case 'invalid_qr':
        return 'QR code non valido';
      default:
        return status;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy - HH:mm').format(dateTime);
  }
}

// ============================================
// TAB: Storico Prenotazioni/Lezioni
// ============================================
class _BookingHistoryTab extends StatelessWidget {
  const _BookingHistoryTab({
    required this.userId,
    required this.bookingRepo,
  });

  final String userId;
  final BookingRepository bookingRepo;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: bookingRepo.getUserBookingsWithAppointments(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Errore nel caricamento\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final bookings = snapshot.data ?? [];

        if (bookings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event,
                  size: 64,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'Nessuna lezione ancora',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Prenota la tua prima lezione\ndalla dashboard',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: bookings.length,
          itemBuilder: (context, index) {
            final item = bookings[index];
            return _BookingCard(bookingData: item);
          },
        );
      },
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.bookingData});

  final Map<String, dynamic> bookingData;

  @override
  Widget build(BuildContext context) {
    final booking = Booking.fromMap(bookingData);
    final appointmentDate = DateTime.parse(bookingData['appointment_date'] as String);
    final appointmentTime = bookingData['appointment_time'] as String;
    final title = bookingData['appointment_title'] as String;
    final description = bookingData['appointment_description'] as String?;

    final isPast = appointmentDate.isBefore(DateTime.now());
    final isCancelled = booking.status == 'cancelled';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isCancelled
                      ? Icons.cancel
                      : isPast
                          ? Icons.check_circle
                          : Icons.event,
                  color: isCancelled
                      ? Colors.red
                      : isPast
                          ? Colors.green
                          : Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (!isCancelled && !isPast)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Prossima',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            if (description != null && description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDate(appointmentDate),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  appointmentTime,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const Spacer(),
                if (isCancelled)
                  const Text(
                    'Cancellata',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }
}

