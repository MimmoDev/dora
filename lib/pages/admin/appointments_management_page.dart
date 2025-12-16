import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/appointment.dart';
import '../../repositories/appointment_repository.dart';
import '../../repositories/auth_repository.dart';
import 'appointment_participants_page.dart';

class AppointmentsManagementPage extends StatefulWidget {
  const AppointmentsManagementPage({super.key});

  @override
  State<AppointmentsManagementPage> createState() =>
      _AppointmentsManagementPageState();
}

class _AppointmentsManagementPageState
    extends State<AppointmentsManagementPage> {
  final _appointmentRepo = AppointmentRepository();

  List<Appointment> _appointments = [];
  bool _isLoading = true;
  DateTime _selectedWeekStart = _getWeekStart(DateTime.now());

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  static DateTime _getWeekStart(DateTime date) {
    final weekday = date.weekday;
    return DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: weekday - 1));
  }

  Future<void> _loadAppointments() async {
    setState(() => _isLoading = true);
    try {
      final appointments =
          await _appointmentRepo.getAppointmentsForWeek(_selectedWeekStart);

      if (mounted) {
        setState(() {
          _appointments = appointments;
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

  void _previousWeek() {
    setState(() {
      _selectedWeekStart = _selectedWeekStart.subtract(const Duration(days: 7));
    });
    _loadAppointments();
  }

  void _nextWeek() {
    setState(() {
      _selectedWeekStart = _selectedWeekStart.add(const Duration(days: 7));
    });
    _loadAppointments();
  }

  void _goToCurrentWeek() {
    setState(() {
      _selectedWeekStart = _getWeekStart(DateTime.now());
    });
    _loadAppointments();
  }

  String _formatWeekRange() {
    final end = _selectedWeekStart.add(const Duration(days: 6));
    return '${_selectedWeekStart.day}/${_selectedWeekStart.month} - ${end.day}/${end.month}/${end.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isCurrentWeek = _selectedWeekStart
        .isAtSameMomentAs(_getWeekStart(DateTime.now()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestione Appuntamenti'),
        actions: [
          IconButton(
            onPressed: _loadAppointments,
            icon: const Icon(Icons.refresh),
            tooltip: 'Ricarica',
          ),
        ],
      ),
      body: Column(
        children: [
          // Week selector
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
                      onPressed: _previousWeek,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          const Text(
                            'Settimana',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            _formatWeekRange(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _nextWeek,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                if (!isCurrentWeek) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _goToCurrentWeek,
                    icon: const Icon(Icons.today, size: 16),
                    label: const Text('Vai alla settimana corrente'),
                  ),
                ],
              ],
            ),
          ),

          // Appointments list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _appointments.isEmpty
                    ? Center(
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
                              'Nessun appuntamento\nper questa settimana',
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
                        itemCount: _appointments.length,
                        itemBuilder: (context, index) {
                          final appointment = _appointments[index];
                          return _AppointmentCard(
                            appointment: appointment,
                            onChanged: _loadAppointments,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      AppointmentParticipantsPage(
                                    appointment: appointment,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showAppointmentDialog(context, null);
        },
        icon: const Icon(Icons.add),
        label: const Text('Nuovo Appuntamento'),
      ),
    );
  }

  void _showAppointmentDialog(BuildContext context, Appointment? appointment) {
    showDialog(
      context: context,
      builder: (context) => _AppointmentDialog(
        appointment: appointment,
        onSaved: _loadAppointments,
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.appointment,
    required this.onChanged,
    required this.onTap,
  });

  final Appointment appointment;
  final VoidCallback onChanged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fillPercentage = appointment.currentParticipants /
        appointment.maxParticipants;
    final isFull = appointment.isFull;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
              children: [
                Icon(
                  Icons.event,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_formatDate(appointment.appointmentDate)} - ${appointment.appointmentTime}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton(
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit),
                          SizedBox(width: 8),
                          Text('Modifica'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text(
                            'Elimina',
                            style: TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showAppointmentDialog(context, appointment);
                    } else if (value == 'delete') {
                      _confirmDelete(context);
                    }
                  },
                ),
              ],
            ),
            if (appointment.description != null) ...[
              const SizedBox(height: 8),
              Text(
                appointment.description!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Partecipanti',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            '${appointment.currentParticipants}/${appointment.maxParticipants}',
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
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.people,
                  size: 14,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  'Tocca per vedere i partecipanti',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final weekdays = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];
    final weekday = weekdays[date.weekday - 1];
    return '$weekday ${date.day}/${date.month}';
  }

  void _showAppointmentDialog(BuildContext context, Appointment? appointment) {
    showDialog(
      context: context,
      builder: (context) => _AppointmentDialog(
        appointment: appointment,
        onSaved: onChanged,
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma eliminazione'),
        content: Text(
          'Sei sicuro di voler eliminare "${appointment.title}"?\n\n'
          'Verranno eliminate anche tutte le prenotazioni associate.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await AppointmentRepository()
                    .deleteAppointment(appointment.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Appuntamento eliminato'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  onChanged();
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Errore: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }
}

class _AppointmentDialog extends StatefulWidget {
  const _AppointmentDialog({
    this.appointment,
    required this.onSaved,
  });

  final Appointment? appointment;
  final VoidCallback onSaved;

  @override
  State<_AppointmentDialog> createState() => _AppointmentDialogState();
}

class _AppointmentDialogState extends State<_AppointmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _authRepo = AuthRepository();
  final _appointmentRepo = AppointmentRepository();
  
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _maxParticipantsController;
  late final TextEditingController _durationController;
  
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.appointment?.title ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.appointment?.description ?? '',
    );
    _maxParticipantsController = TextEditingController(
      text: (widget.appointment?.maxParticipants ?? 10).toString(),
    );
    _durationController = TextEditingController(
      text: (widget.appointment?.durationMinutes ?? 60).toString(),
    );
    
    if (widget.appointment != null) {
      _selectedDate = widget.appointment!.appointmentDate;
      final timeParts = widget.appointment!.appointmentTime.split(':');
      _selectedTime = TimeOfDay(
        hour: int.parse(timeParts[0]),
        minute: int.parse(timeParts[1]),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _maxParticipantsController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (time != null) {
      setState(() => _selectedTime = time);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona una data')),
      );
      return;
    }
    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona un orario')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final timeString =
          '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}:00';

      if (widget.appointment == null) {
        // Crea nuovo
        await _appointmentRepo.createAppointment(
          appointmentDate: _selectedDate!,
          appointmentTime: timeString,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          maxParticipants: int.parse(_maxParticipantsController.text),
          durationMinutes: int.parse(_durationController.text),
          createdBy: _authRepo.currentUser?.id ?? 'unknown',
        );
      } else {
        // Aggiorna esistente
        await _appointmentRepo.updateAppointment(
          widget.appointment!.id,
          {
            'appointment_date': _selectedDate!.toIso8601String().split('T')[0],
            'appointment_time': timeString,
            'title': _titleController.text.trim(),
            'description': _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            'max_participants': int.parse(_maxParticipantsController.text),
            'duration_minutes': int.parse(_durationController.text),
          },
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.appointment == null
                  ? '✅ Appuntamento creato!'
                  : '✅ Appuntamento aggiornato!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        widget.onSaved();
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.appointment == null
            ? 'Nuovo Appuntamento'
            : 'Modifica Appuntamento',
      ),
      content: _isLoading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          : SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Titolo*',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Campo obbligatorio';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Descrizione',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _selectDate,
                            icon: const Icon(Icons.calendar_today),
                            label: Text(
                              _selectedDate == null
                                  ? 'Seleziona data'
                                  : DateFormat('dd/MM/yyyy')
                                      .format(_selectedDate!),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _selectTime,
                            icon: const Icon(Icons.access_time),
                            label: Text(
                              _selectedTime == null
                                  ? 'Orario'
                                  : '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _maxParticipantsController,
                            decoration: const InputDecoration(
                              labelText: 'Max partecipanti*',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Obbligatorio';
                              }
                              final num = int.tryParse(value);
                              if (num == null || num <= 0) {
                                return 'Numero non valido';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _durationController,
                            decoration: const InputDecoration(
                              labelText: 'Durata (min)*',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Obbligatorio';
                              }
                              final num = int.tryParse(value);
                              if (num == null || num <= 0) {
                                return 'Non valido';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _save,
          child: Text(widget.appointment == null ? 'Crea' : 'Salva'),
        ),
      ],
    );
  }
}

