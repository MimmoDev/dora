import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../repositories/check_in_repository.dart';

class CheckInsManagementPage extends StatefulWidget {
  const CheckInsManagementPage({super.key});

  @override
  State<CheckInsManagementPage> createState() =>
      _CheckInsManagementPageState();
}

class _CheckInsManagementPageState extends State<CheckInsManagementPage> {
  final _checkInRepo = CheckInRepository();
  
  List<Map<String, dynamic>> _checkIns = [];
  Map<String, int> _stats = {};
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final checkIns = await _checkInRepo.getCheckInsByDate(_selectedDate);
      
      // Calcola statistiche
      final stats = <String, int>{
        'total': checkIns.length,
        'valid': 0,
        'late': 0,
        'early': 0,
        'no_booking': 0,
        'other': 0,
      };

      for (final checkIn in checkIns) {
        final status = checkIn['status'] as String;
        if (stats.containsKey(status)) {
          stats[status] = (stats[status] ?? 0) + 1;
        } else {
          stats['other'] = (stats['other'] ?? 0) + 1;
        }
      }

      if (mounted) {
        setState(() {
          _checkIns = checkIns;
          _stats = stats;
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

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isToday = _selectedDate.day == DateTime.now().day &&
        _selectedDate.month == DateTime.now().month &&
        _selectedDate.year == DateTime.now().year;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestione Check-in'),
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Ricarica',
          ),
        ],
      ),
      body: Column(
        children: [
          // Date selector
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                ),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _selectedDate = _selectedDate.subtract(
                            const Duration(days: 1),
                          );
                        });
                        _loadData();
                      },
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: _selectDate,
                        child: Column(
                          children: [
                            const Text(
                              'Data',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  DateFormat('dd/MM/yyyy').format(_selectedDate),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.calendar_today, size: 16),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _selectedDate.isBefore(DateTime.now())
                          ? () {
                              setState(() {
                                _selectedDate = _selectedDate.add(
                                  const Duration(days: 1),
                                );
                              });
                              _loadData();
                            }
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                if (!isToday) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () {
                      setState(() => _selectedDate = DateTime.now());
                      _loadData();
                    },
                    icon: const Icon(Icons.today, size: 16),
                    label: const Text('Vai a oggi'),
                  ),
                ],
              ],
            ),
          ),

          // Stats
          if (!_isLoading && _checkIns.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Statistiche del giorno',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatBadge(
                            label: 'Totale',
                            value: _stats['total'] ?? 0,
                            color: Colors.blue,
                            icon: Icons.people,
                          ),
                          _StatBadge(
                            label: 'Validi',
                            value: _stats['valid'] ?? 0,
                            color: Colors.green,
                            icon: Icons.check_circle,
                          ),
                          _StatBadge(
                            label: 'In ritardo',
                            value: _stats['late'] ?? 0,
                            color: Colors.orange,
                            icon: Icons.schedule,
                          ),
                          _StatBadge(
                            label: 'Altro',
                            value: (_stats['early'] ?? 0) +
                                (_stats['no_booking'] ?? 0) +
                                (_stats['other'] ?? 0),
                            color: Colors.grey,
                            icon: Icons.info,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Check-ins list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _checkIns.isEmpty
                    ? Center(
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
                              'Nessun check-in\nper questa data',
                              textAlign: TextAlign.center,
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
                        itemCount: _checkIns.length,
                        itemBuilder: (context, index) {
                          final checkIn = _checkIns[index];
                          return _CheckInCard(checkIn: checkIn);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final int value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

class _CheckInCard extends StatelessWidget {
  const _CheckInCard({required this.checkIn});

  final Map<String, dynamic> checkIn;

  @override
  Widget build(BuildContext context) {
    final status = checkIn['status'] as String;
    final checkedInAt = DateTime.parse(checkIn['checked_in_at'] as String);
    final profile = checkIn['profiles'] as Map<String, dynamic>?;
    final appointment = checkIn['appointments'] as Map<String, dynamic>?;
    
    final userName = profile != null
        ? '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}'.trim()
        : 'Utente sconosciuto';
    
    final appointmentTitle = appointment?['title'] as String?;
    final appointmentTime = appointment?['appointment_time'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(status).withOpacity(0.2),
          child: Icon(
            _getStatusIcon(status),
            color: _getStatusColor(status),
          ),
        ),
        title: Text(
          userName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(DateFormat('HH:mm').format(checkedInAt)),
                const SizedBox(width: 16),
                Icon(
                  _getStatusIcon(status),
                  size: 14,
                  color: _getStatusColor(status),
                ),
                const SizedBox(width: 4),
                Text(
                  _getStatusLabel(status),
                  style: TextStyle(
                    color: _getStatusColor(status),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (appointmentTitle != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.event,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text('$appointmentTitle'),
                  if (appointmentTime != null) ...[
                    const SizedBox(width: 4),
                    Text('($appointmentTime)'),
                  ],
                ],
              ),
            ],
          ],
        ),
        trailing: status == 'valid'
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
      case 'invalid_qr':
        return Icons.qr_code;
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
        return 'Valido';
      case 'late':
        return 'In ritardo';
      case 'early':
        return 'Troppo presto';
      case 'no_booking':
        return 'Nessuna prenotazione';
      case 'invalid_qr':
        return 'QR non valido';
      default:
        return status;
    }
  }
}




