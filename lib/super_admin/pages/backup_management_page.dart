import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class BackupManagementPage extends StatefulWidget {
  const BackupManagementPage({super.key});

  @override
  State<BackupManagementPage> createState() => _BackupManagementPageState();
}

class _BackupManagementPageState extends State<BackupManagementPage> {
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  bool _isLoading = true;
  bool _isCreatingBackup = false;
  String? _error;
  List<Map<String, dynamic>> _backupHistory = [];
  Map<String, dynamic>? _latestBackup;

  // Collections that can be backed up
  final List<String> _availableCollections = [
    'users',
    'stores',
    'orders',
    'products',
    'reviews',
    'discounts',
    'notifications',
    'super_admins',
    'admin_activity_logs',
    'analytics_events',
    'categories'
  ];

  // Selected collections for manual backup
  final Set<String> _selectedCollections = {};

  @override
  void initState() {
    super.initState();
    _loadBackupHistory();
  }

  Future<void> _loadBackupHistory() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final callable = _functions.httpsCallable('getBackupHistory');
      final result = await callable.call({'limit': 20});

      if (result.data['success']) {
        final backups = List<Map<String, dynamic>>.from(result.data['backups']);

        setState(() {
          _backupHistory = backups;
          _latestBackup = backups.isNotEmpty ? backups.first : null;
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load backup history');
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load backup history: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _triggerManualBackup() async {
    if (_selectedCollections.isEmpty) {
      _showSnackBar(
          'Please select at least one collection to backup', Colors.orange);
      return;
    }
    setState(() {
      _isCreatingBackup = true;
    });
    try {
      final callable = _functions.httpsCallable('triggerManualBackup');
      final result = await callable.call({
        'collections': _selectedCollections.toList(),
      });
      if (result.data['success']) {
        _showSnackBar('Backup completed successfully!', Colors.green);
        _selectedCollections.clear();
        await _loadBackupHistory(); // Refresh the history
      } else {
        throw Exception(result.data['message'] ?? 'Backup failed');
      }
    } catch (e) {
      _showSnackBar('Backup failed: $e', Colors.red);
    } finally {
      setState(() {
        _isCreatingBackup = false;
      });
    }
  }

  Future<void> _showRestoreDialog(Map<String, dynamic> backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _RestoreConfirmationDialog(
        backup: backup,
        availableCollections: List<String>.from(backup['collections'] ?? []),
      ),
    );

    if (confirmed == true) {
      await _performRestore(backup);
    }
  }

  Future<void> _performRestore(Map<String, dynamic> backup) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Restoring data... This may take several minutes.'),
            ],
          ),
        ),
      );

      final callable = _functions.httpsCallable('restoreFromBackup');
      final result = await callable.call({
        'backupPath': backup['backupPath'],
        'collections': backup['collections'],
        'confirmationCode': 'RESTORE_CONFIRMED',
      });

      Navigator.of(context).pop(); // Close loading dialog

      if (result.data['success']) {
        _showSnackBar(
          'Data restored successfully! ${result.data['restore']['restoredCount']} documents restored.',
          Colors.green,
        );
      } else {
        throw Exception(result.data['message'] ?? 'Restore failed');
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      _showSnackBar('Restore failed: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is String) {
      date = DateTime.tryParse(timestamp) ??
          DateTime.fromMillisecondsSinceEpoch(int.tryParse(timestamp) ?? 0);
    } else if (timestamp is int) {
      date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    } else {
      return 'Invalid date';
    }
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'success':
        return Colors.green;
      case 'failed':
        return Colors.red;
      case 'in_progress':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'success':
        return Icons.check_circle;
      case 'failed':
        return Icons.error;
      case 'in_progress':
        return Icons.hourglass_empty;
      default:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade50,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : _buildContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
          const SizedBox(height: 16),
          Text(
            'Failed to load backup data',
            style: TextStyle(fontSize: 20, color: Colors.red.shade600),
          ),
          const SizedBox(height: 8),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadBackupHistory,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildStatusCards(),
          const SizedBox(height: 24),
          _buildManualBackupSection(),
          const SizedBox(height: 24),
          _buildBackupHistory(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.backup, size: 32, color: Colors.blue),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Backup Management',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Manage automated backups and restore data when needed',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: _loadBackupHistory,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatusCard(
            'Last Backup',
            _latestBackup != null
                ? _formatDate(_latestBackup!['timestamp'])
                : 'No backups',
            _latestBackup != null
                ? _getStatusIcon(_latestBackup!['status'])
                : Icons.warning,
            _latestBackup != null
                ? _getStatusColor(_latestBackup!['status'])
                : Colors.orange,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatusCard(
            'Total Backups',
            _backupHistory.length.toString(),
            Icons.folder,
            Colors.purple,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatusCard(
            'Storage Used',
            _latestBackup != null
                ? _formatFileSize(_latestBackup!['size'] ?? 0)
                : '0 MB',
            Icons.storage,
            Colors.green,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatusCard(
            'Next Backup',
            'Daily at 2:00 AM UTC',
            Icons.schedule,
            Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualBackupSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.play_circle, color: Colors.blue, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Manual Backup',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (_isCreatingBackup)
                const Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Creating backup...'),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Select collections to backup:',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableCollections.map((collection) {
              final isSelected = _selectedCollections.contains(collection);
              return FilterChip(
                label: Text(collection),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedCollections.add(collection);
                    } else {
                      _selectedCollections.remove(collection);
                    }
                  });
                },
                selectedColor: Colors.blue.shade100,
                checkmarkColor: Colors.blue,
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedCollections.clear();
                    _selectedCollections.addAll(_availableCollections);
                  });
                },
                child: const Text('Select All'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedCollections.clear();
                  });
                },
                child: const Text('Clear All'),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _isCreatingBackup ? null : _triggerManualBackup,
                icon: const Icon(Icons.backup),
                label: const Text('Create Backup'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBackupHistory() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history, color: Colors.blue, size: 24),
              SizedBox(width: 8),
              Text(
                'Backup History',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_backupHistory.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.folder_open, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('No backups found'),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _backupHistory.length,
              itemBuilder: (context, index) {
                final backup = _backupHistory[index];
                return _buildBackupItem(backup);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildBackupItem(Map<String, dynamic> backup) {
    final status = backup['status'] ?? 'unknown';
    final collections = List<String>.from(backup['collections'] ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            _getStatusIcon(status),
            color: _getStatusColor(status),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _formatDate(backup['timestamp']),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: _getStatusColor(status),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${backup['documentCount'] ?? 0} documents • ${_formatFileSize(backup['size'] ?? 0)}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  'Collections: ${collections.join(', ')}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (status == 'success')
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'restore') {
                  _showRestoreDialog(backup);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'restore',
                  child: Row(
                    children: [
                      Icon(Icons.restore, size: 16),
                      SizedBox(width: 8),
                      Text('Restore'),
                    ],
                  ),
                ),
              ],
              child: const Icon(Icons.more_vert),
            ),
        ],
      ),
    );
  }
}

class _RestoreConfirmationDialog extends StatefulWidget {
  final Map<String, dynamic> backup;
  final List<String> availableCollections;

  const _RestoreConfirmationDialog({
    required this.backup,
    required this.availableCollections,
  });

  @override
  State<_RestoreConfirmationDialog> createState() =>
      _RestoreConfirmationDialogState();
}

class _RestoreConfirmationDialogState
    extends State<_RestoreConfirmationDialog> {
  final Set<String> _selectedCollections = {};
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    _selectedCollections.addAll(widget.availableCollections);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning, color: Colors.red),
          SizedBox(width: 8),
          Text('Restore Data'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: const Text(
                '⚠️ WARNING: This will overwrite existing data in the selected collections. This action cannot be undone!',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 16),
            Text('Backup from: ${_formatDate(widget.backup['timestamp'])}'),
            Text('Documents: ${widget.backup['documentCount'] ?? 0}'),
            const SizedBox(height: 16),
            const Text(
              'Select collections to restore:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ...widget.availableCollections.map((collection) {
              return CheckboxListTile(
                title: Text(collection),
                value: _selectedCollections.contains(collection),
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedCollections.add(collection);
                    } else {
                      _selectedCollections.remove(collection);
                    }
                  });
                },
                dense: true,
              );
            }),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text(
                'I understand this will overwrite existing data',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              value: _confirmed,
              onChanged: (value) {
                setState(() {
                  _confirmed = value == true;
                });
              },
              activeColor: Colors.red,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _confirmed && _selectedCollections.isNotEmpty
              ? () => Navigator.of(context).pop(true)
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Restore Data'),
        ),
      ],
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';

    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is String) {
      date = DateTime.parse(timestamp);
    } else {
      return 'Invalid date';
    }

    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
