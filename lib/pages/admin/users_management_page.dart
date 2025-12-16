import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/profile.dart';
import '../../models/subscription.dart';
import '../../repositories/profile_repository.dart';
import '../../repositories/subscription_repository.dart';

class UsersManagementPage extends StatefulWidget {
  const UsersManagementPage({super.key});

  @override
  State<UsersManagementPage> createState() => _UsersManagementPageState();
}

class _UsersManagementPageState extends State<UsersManagementPage> {
  final _profileRepo = ProfileRepository();
  final _subscriptionRepo = SubscriptionRepository();

  List<Profile> _users = [];
  Map<String, Subscription?> _subscriptions = {};
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await _profileRepo.fetchProfiles();
      final subscriptions = <String, Subscription?>{};

      for (final user in users) {
        final sub = await _subscriptionRepo.getActiveSubscription(user.id);
        subscriptions[user.id] = sub;
      }

      if (mounted) {
        setState(() {
          _users = users;
          _subscriptions = subscriptions;
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

  List<Profile> get _filteredUsers {
    if (_searchQuery.isEmpty) return _users;
    
    final query = _searchQuery.toLowerCase();
    return _users.where((user) {
      final fullName = '${user.firstName} ${user.lastName}'.toLowerCase();
      return fullName.contains(query) || 
             (user.phone?.contains(query) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestione Utenti'),
        actions: [
          IconButton(
            onPressed: _loadUsers,
            icon: const Icon(Icons.refresh),
            tooltip: 'Ricarica',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Cerca per nome o telefono...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // Users list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
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
                              _searchQuery.isEmpty
                                  ? 'Nessun utente'
                                  : 'Nessun risultato',
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
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = _filteredUsers[index];
                          final subscription = _subscriptions[user.id];
                          return _UserCard(
                            user: user,
                            subscription: subscription,
                            onSubscriptionChanged: _loadUsers,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.subscription,
    required this.onSubscriptionChanged,
  });

  final Profile user;
  final Subscription? subscription;
  final VoidCallback onSubscriptionChanged;

  @override
  Widget build(BuildContext context) {
    final hasActiveSubscription = subscription?.isActive ?? false;
    final isAdmin = user.role == 'admin';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isAdmin
              ? Colors.red
              : hasActiveSubscription
                  ? Colors.green
                  : Colors.grey,
          child: Text(
            _getInitials(user),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                '${user.firstName ?? ''} ${user.lastName ?? ''}'.trim(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (isAdmin)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'ADMIN',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (user.phone != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.phone, size: 14),
                  const SizedBox(width: 4),
                  Text(user.phone!),
                ],
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  hasActiveSubscription
                      ? Icons.check_circle
                      : Icons.cancel,
                  size: 14,
                  color: hasActiveSubscription ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  hasActiveSubscription
                      ? 'Abbonamento attivo'
                      : 'Nessun abbonamento',
                  style: TextStyle(
                    color: hasActiveSubscription ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (subscription != null && hasActiveSubscription) ...[
              const SizedBox(height: 4),
              Text(
                'Scade: ${_formatDate(subscription!.endDate!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ],
        ),
        trailing: !isAdmin
            ? IconButton(
                onPressed: () {
                  _showSubscriptionDialog(context, user, subscription);
                },
                icon: const Icon(Icons.edit),
                tooltip: 'Gestisci abbonamento',
              )
            : null,
        onTap: () {
          _showUserDetails(context, user, subscription);
        },
      ),
    );
  }

  String _getInitials(Profile user) {
    final firstName = user.firstName ?? '';
    final lastName = user.lastName ?? '';
    return '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'
        .toUpperCase();
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  void _showUserDetails(
    BuildContext context,
    Profile user,
    Subscription? subscription,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${user.firstName} ${user.lastName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow(
              icon: Icons.person,
              label: 'Nome',
              value: '${user.firstName ?? ''} ${user.lastName ?? ''}',
            ),
            if (user.phone != null)
              _DetailRow(
                icon: Icons.phone,
                label: 'Telefono',
                value: user.phone!,
              ),
            _DetailRow(
              icon: Icons.badge,
              label: 'Ruolo',
              value: user.role == 'admin' ? 'Amministratore' : 'Utente',
            ),
            const Divider(height: 24),
            if (subscription != null) ...[
              _DetailRow(
                icon: Icons.card_membership,
                label: 'Abbonamento',
                value: subscription.isActive ? 'Attivo' : 'Non attivo',
              ),
              if (subscription.isActive) ...[
                _DetailRow(
                  icon: Icons.calendar_today,
                  label: 'Inizio',
                  value: _formatDate(subscription.startDate!),
                ),
                _DetailRow(
                  icon: Icons.event,
                  label: 'Scadenza',
                  value: _formatDate(subscription.endDate!),
                ),
                _DetailRow(
                  icon: Icons.schedule,
                  label: 'Giorni rimanenti',
                  value: '${subscription.daysUntilExpiry ?? 0} giorni',
                ),
              ],
            ] else
              const Text(
                'Nessun abbonamento attivo',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Chiudi'),
          ),
          if (user.role != 'admin')
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _showSubscriptionDialog(context, user, subscription);
              },
              icon: const Icon(Icons.edit),
              label: const Text('Gestisci Abbonamento'),
            ),
        ],
      ),
    );
  }

  void _showSubscriptionDialog(
    BuildContext context,
    Profile user,
    Subscription? subscription,
  ) {
    showDialog(
      context: context,
      builder: (context) => _SubscriptionDialog(
        user: user,
        subscription: subscription,
        onChanged: onSubscriptionChanged,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionDialog extends StatefulWidget {
  const _SubscriptionDialog({
    required this.user,
    required this.subscription,
    required this.onChanged,
  });

  final Profile user;
  final Subscription? subscription;
  final VoidCallback onChanged;

  @override
  State<_SubscriptionDialog> createState() => _SubscriptionDialogState();
}

class _SubscriptionDialogState extends State<_SubscriptionDialog> {
  final _subscriptionRepo = SubscriptionRepository();
  bool _isLoading = false;
  String _selectedType = 'monthly';
  int _durationMonths = 1;

  @override
  void initState() {
    super.initState();
    if (widget.subscription != null) {
      _selectedType = widget.subscription!.type;
    }
  }

  Future<void> _activateSubscription() async {
    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      
      // Se c'è già un abbonamento attivo, estendi da quella data
      // Altrimenti inizia da oggi
      final startDate = widget.subscription != null && 
                        widget.subscription!.isActive &&
                        widget.subscription!.endDate != null &&
                        widget.subscription!.endDate!.isAfter(now)
          ? widget.subscription!.endDate!
          : now;
      
      final endDate = DateTime(
        startDate.year,
        startDate.month + _durationMonths,
        startDate.day,
      );

      // Ottieni l'ID dell'admin corrente
      // TODO: usare current user da AuthRepository se serve audit
      final adminId = null;
      if (adminId == null) {
        throw Exception('Admin non autenticato');
      }

      await _subscriptionRepo.activateSubscription(
        userId: widget.user.id,
        subscriptionType: _selectedType,
        startDate: startDate, // Usa la data calcolata correttamente
        endDate: endDate,
        activatedBy: adminId, // ID dell'admin che attiva l'abbonamento
      );

      if (mounted) {
        Navigator.pop(context);
        final isExtension = widget.subscription != null && 
                           widget.subscription!.isActive;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isExtension
                  ? '✅ Abbonamento esteso con successo!'
                  : '✅ Abbonamento attivato con successo!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        widget.onChanged();
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

  Future<void> _deactivateSubscription() async {
    setState(() => _isLoading = true);

    try {
      await _subscriptionRepo.deactivateSubscription(widget.subscription!.id);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Abbonamento disattivato'),
            backgroundColor: Colors.orange,
          ),
        );
        widget.onChanged();
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
    final hasActiveSubscription = widget.subscription?.isActive ?? false;

    return AlertDialog(
      title: Text(
        hasActiveSubscription
            ? 'Gestisci Abbonamento'
            : 'Attiva Abbonamento',
      ),
      content: _isLoading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.user.firstName} ${widget.user.lastName}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (hasActiveSubscription) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green),
                              SizedBox(width: 8),
                              Text(
                                'Abbonamento Attivo',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Tipo: ${_getTypeLabel(widget.subscription!.type)}',
                          ),
                          Text(
                            'Scadenza: ${DateFormat('dd/MM/yyyy').format(widget.subscription!.endDate!)}',
                          ),
                          Text(
                            'Giorni rimanenti: ${widget.subscription!.daysUntilExpiry}',
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    const Text(
                      'Seleziona tipo di abbonamento:',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedType,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Tipo',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'monthly',
                          child: Text('Mensile'),
                        ),
                        DropdownMenuItem(
                          value: 'quarterly',
                          child: Text('Trimestrale'),
                        ),
                        DropdownMenuItem(
                          value: 'annual',
                          child: Text('Annuale'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedType = value!;
                          _durationMonths = value == 'monthly'
                              ? 1
                              : value == 'quarterly'
                                  ? 3
                                  : 12;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: _durationMonths.toString(),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Durata (mesi)',
                        helperText: 'Personalizza la durata',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        final months = int.tryParse(value);
                        if (months != null && months > 0) {
                          _durationMonths = months;
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        if (hasActiveSubscription) ...[
          FilledButton.icon(
            onPressed: _isLoading ? null : _activateSubscription,
            icon: const Icon(Icons.add),
            label: const Text('Estendi'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _isLoading ? null : _deactivateSubscription,
            icon: const Icon(Icons.cancel),
            label: const Text('Disattiva'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
          ),
        ] else
          FilledButton.icon(
            onPressed: _isLoading ? null : _activateSubscription,
            icon: const Icon(Icons.check_circle),
            label: const Text('Attiva'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green,
            ),
          ),
      ],
    );
  }

  String _getTypeLabel(String type) {
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
}

