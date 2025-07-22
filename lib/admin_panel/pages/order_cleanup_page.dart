import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../widgets/top_nav_bar.dart';
import '../widgets/side_menu.dart';
import '../../features/settings/themes/app_themes.dart';

class OrderCleanupPage extends StatefulWidget {
  const OrderCleanupPage({super.key});

  @override
  State<OrderCleanupPage> createState() => _OrderCleanupPageState();
}

class _OrderCleanupPageState extends State<OrderCleanupPage> {
  bool _isLoading = false;
  String _lastCleanupStatus = '';
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemes.getBackgroundColor(context),
      body: Row(
        children: [
          const SideMenu(selected: 'Захиалгын цэвэрлэлт'),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TopNavBar(title: 'Захиалгын цэвэрлэлт'),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 24),
                        _buildCleanupInfo(),
                        const SizedBox(height: 24),
                        _buildCleanupActions(),
                        const SizedBox(height: 24),
                        _buildStatusSection(),
                      ],
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

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Захиалгын цэвэрлэлт',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Хүргэгдсэн захиалгуудыг автоматаар цэвэрлэх, архивлах',
          style: TextStyle(
            fontSize: 16,
            color: AppThemes.getSecondaryTextColor(context),
          ),
        ),
      ],
    );
  }

  Widget _buildCleanupInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppThemes.getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppThemes.getBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade600, size: 24),
              const SizedBox(width: 12),
              const Text(
                'Цэвэрлэлтийн дүрэм',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildRuleItem(
            '30 хоног',
            'Хүргэгдсэн захиалгуудыг архивлах',
            Colors.orange,
            Icons.archive,
          ),
          _buildRuleItem(
            '90 хоног',
            'Архивлагдсан захиалгуудыг шахах',
            Colors.purple,
            Icons.compress,
          ),
          _buildRuleItem(
            '1 жил',
            'Хуучин захиалгуудыг устгах',
            Colors.red,
            Icons.delete_forever,
          ),
        ],
      ),
    );
  }

  Widget _buildRuleItem(
      String time, String description, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  time,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: AppThemes.getSecondaryTextColor(context),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCleanupActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppThemes.getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppThemes.getBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cleaning_services,
                  color: Colors.green.shade600, size: 24),
              const SizedBox(width: 12),
              const Text(
                'Цэвэрлэлтийн үйлдлүүд',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  'Архивлах',
                  '30 хоногийн захиалгуудыг архивлэх',
                  Colors.orange,
                  Icons.archive,
                  () => _runCleanup('archive'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  'Шахах',
                  '90 хоногийн архивлагдсан захиалгуудыг шахах',
                  Colors.purple,
                  Icons.compress,
                  () => _runCleanup('compress'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  'Устгах',
                  '1 жилийн хуучин захиалгуудыг устгах',
                  Colors.red,
                  Icons.delete_forever,
                  () => _runCleanup('delete'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: _buildActionButton(
              'Бүгдийг цэвэрлэх',
              'Бүх цэвэрлэлтийн үйлдлийг дарааллаар гүйцэтгэх',
              Colors.blue,
              Icons.cleaning_services,
              () => _runCleanup('all'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String title,
    String subtitle,
    Color color,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return ElevatedButton(
      onPressed: _isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppThemes.getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppThemes.getBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, color: Colors.grey.shade600, size: 24),
              const SizedBox(width: 12),
              const Text(
                'Сүүлийн цэвэрлэлт',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 12),
                Text('Цэвэрлэлт хийж байна...'),
              ],
            )
          else if (_lastCleanupStatus.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle,
                      color: Colors.green.shade600, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _lastCleanupStatus,
                      style: TextStyle(color: Colors.green.shade700),
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              'Цэвэрлэлт хийгээгүй байна',
              style: TextStyle(
                color: AppThemes.getSecondaryTextColor(context),
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _runCleanup(String action) async {
    setState(() {
      _isLoading = true;
      _lastCleanupStatus = '';
    });

    try {
      final result = await _functions.httpsCallable('manualOrderCleanup').call({
        'action': action,
      });

      final data = result.data as Map<String, dynamic>;

      if (data['success'] == true) {
        setState(() {
          _lastCleanupStatus =
              'Цэвэрлэлт амжилттай дууслаа: ${_formatResult(data['result'])}';
        });
      } else {
        setState(() {
          _lastCleanupStatus = 'Цэвэрлэлт амжилтгүй болсон';
        });
      }
    } catch (e) {
      setState(() {
        _lastCleanupStatus = 'Алдаа гарлаа: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatResult(dynamic result) {
    if (result is Map<String, dynamic>) {
      if (result.containsKey('archivedCount')) {
        return '${result['archivedCount']} захиалга архивлагдлаа';
      } else if (result.containsKey('compressedCount')) {
        return '${result['compressedCount']} захиалга шагдлаа';
      } else if (result.containsKey('deletedCount')) {
        return '${result['deletedCount']} захиалга устгагдлаа';
      } else if (result.containsKey('archive') ||
          result.containsKey('compress') ||
          result.containsKey('delete')) {
        final parts = <String>[];
        if (result['archive'] != null)
          parts.add('Архив: ${result['archive']['archivedCount'] ?? 0}');
        if (result['compress'] != null)
          parts.add('Шахалт: ${result['compress']['compressedCount'] ?? 0}');
        if (result['delete'] != null)
          parts.add('Устгалт: ${result['delete']['deletedCount'] ?? 0}');
        return parts.join(', ');
      }
    }
    return 'Цэвэрлэлт дууслаа';
  }
}
