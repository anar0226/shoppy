import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../features/commission/models/commission_model.dart';
import '../../features/commission/services/commission_service.dart';
import '../../features/commission/models/payout_model.dart';
import '../../features/commission/services/payout_service.dart';

class CommissionManagementPage extends StatefulWidget {
  const CommissionManagementPage({super.key});

  @override
  State<CommissionManagementPage> createState() =>
      _CommissionManagementPageState();
}

class _CommissionManagementPageState extends State<CommissionManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final CommissionService _commissionService = CommissionService();

  CommissionSummary? _summary;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadCommissionSummary();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCommissionSummary() async {
    try {
      final summary = await _commissionService.getCommissionSummary();
      if (mounted) {
        setState(() {
          _summary = summary;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading commission data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          // Header with summary cards
          Container(
            padding: const EdgeInsets.all(24),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet,
                        color: Colors.blue, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      'Commission Management',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _initializeCommissionRules,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Initialize Rules'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  _buildSummaryCards(),
              ],
            ),
          ),

          // Tab Bar
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Commission Rules'),
                Tab(text: 'Transactions'),
                Tab(text: 'Analytics'),
                Tab(text: 'Payouts'),
              ],
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blue,
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _CommissionRulesTab(commissionService: _commissionService),
                _CommissionTransactionsTab(
                    commissionService: _commissionService),
                _CommissionAnalyticsTab(commissionService: _commissionService),
                _CommissionPayoutsTab(commissionService: _commissionService),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Total Commission',
            _summary?.formattedTotalCommission ?? '\$0.00',
            Icons.account_balance_wallet,
            Colors.blue,
            '${_summary?.totalTransactions ?? 0} transactions',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            'Pending Commission',
            _summary?.formattedPendingCommissions ?? '\$0.00',
            Icons.hourglass_empty,
            Colors.orange,
            '${_summary?.pendingTransactions ?? 0} pending',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            'Collected Commission',
            _summary?.formattedPaidCommissions ?? '\$0.00',
            Icons.check_circle,
            Colors.green,
            'Last 30 days',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            'Average Commission',
            '₮${_summary?.averageCommissionPerTransaction.toStringAsFixed(2) ?? '0.00'}',
            Icons.trending_up,
            Colors.purple,
            'Per transaction',
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
      String title, String value, IconData icon, Color color, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _initializeCommissionRules() async {
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('initializeCommissionRules');
      final result = await callable.call();

      if (mounted) {
        final data = Map<String, dynamic>.from(result.data);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Commission rules processed'),
            backgroundColor:
                data['success'] == true ? Colors.green : Colors.orange,
          ),
        );
        if (data['success'] == true) {
          _loadCommissionSummary();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// Commission Rules Tab
class _CommissionRulesTab extends StatelessWidget {
  final CommissionService commissionService;

  const _CommissionRulesTab({required this.commissionService});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Commission Rules',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showCreateRuleDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Rule'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<CommissionRule>>(
              stream: commissionService.getCommissionRules(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text(
                        'No commission rules found. Initialize default rules to get started.'),
                  );
                }

                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final rule = snapshot.data![index];
                    return _buildRuleCard(context, rule);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleCard(BuildContext context, CommissionRule rule) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  rule.storeId != null ? Icons.store : Icons.public,
                  color: Colors.blue,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  rule.storeId != null
                      ? 'Store Specific'
                      : rule.category != null
                          ? 'Category: ${rule.category}'
                          : 'Global Rule',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Chip(
                  label: Text(rule.isActive ? 'Active' : 'Inactive'),
                  backgroundColor: rule.isActive
                      ? Colors.green.shade100
                      : Colors.red.shade100,
                  labelStyle: TextStyle(
                    color: rule.isActive
                        ? Colors.green.shade800
                        : Colors.red.shade800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton(
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showEditRuleDialog(context, rule);
                    } else if (value == 'delete') {
                      _deleteRule(context, rule);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildRuleDetail(
                    'Type', rule.type.toString().split('.').last.toUpperCase()),
                const SizedBox(width: 24),
                _buildRuleDetail(
                    'Value',
                    rule.type == CommissionType.percentage
                        ? '${rule.value}%'
                        : '\$${rule.value.toStringAsFixed(2)}'),
                const SizedBox(width: 24),
                _buildRuleDetail(
                    'Min Order', '₮${rule.minOrderValue.toStringAsFixed(2)}'),
                if (rule.maxCommission != double.infinity) ...[
                  const SizedBox(width: 24),
                  _buildRuleDetail('Max Commission',
                      '₮${rule.maxCommission.toStringAsFixed(2)}'),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  void _showCreateRuleDialog(BuildContext context) {
    // Implementation for create rule dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Commission Rule'),
        content: const Text(
            'Commission rule creation dialog would be implemented here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showEditRuleDialog(BuildContext context, CommissionRule rule) {
    // Implementation for edit rule dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Commission Rule'),
        content: const Text(
            'Commission rule editing dialog would be implemented here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteRule(BuildContext context, CommissionRule rule) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Commission Rule'),
        content:
            const Text('Are you sure you want to delete this commission rule?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await CommissionService().deleteCommissionRule(rule.id);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Commission rule deleted successfully')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error deleting rule: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// Commission Transactions Tab
class _CommissionTransactionsTab extends StatelessWidget {
  final CommissionService commissionService;

  const _CommissionTransactionsTab({required this.commissionService});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Commission Transactions',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<CommissionTransaction>>(
              stream: commissionService.getAllCommissionTransactions(limit: 50),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text('No commission transactions found.'),
                  );
                }

                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final transaction = snapshot.data![index];
                    return _buildTransactionCard(context, transaction);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(
      BuildContext context, CommissionTransaction transaction) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.receipt,
                  color: Colors.blue,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Order #${transaction.orderId.substring(0, 8)}...',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Chip(
                  label: Text(transaction.status
                      .toString()
                      .split('.')
                      .last
                      .toUpperCase()),
                  backgroundColor:
                      _getStatusColor(transaction.status).withOpacity(0.1),
                  labelStyle: TextStyle(
                    color: _getStatusColor(transaction.status),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildTransactionDetail(
                    'Order Total', transaction.formattedOrderTotal),
                const SizedBox(width: 24),
                _buildTransactionDetail(
                    'Commission', transaction.formattedCommissionAmount),
                const SizedBox(width: 24),
                _buildTransactionDetail(
                    'Vendor Amount', transaction.formattedVendorAmount),
                const SizedBox(width: 24),
                _buildTransactionDetail('Commission %',
                    '${transaction.commissionPercentage.toStringAsFixed(1)}%'),
              ],
            ),
            if (transaction.paidAt != null) ...[
              const SizedBox(height: 8),
              Text(
                'Paid: ${transaction.paidAt!.toLocal().toString().split('.')[0]}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(CommissionStatus status) {
    switch (status) {
      case CommissionStatus.pending:
        return Colors.orange;
      case CommissionStatus.calculated:
        return Colors.blue;
      case CommissionStatus.paid:
        return Colors.green;
      case CommissionStatus.disputed:
        return Colors.red;
    }
  }
}

// Placeholder tabs
class _CommissionAnalyticsTab extends StatelessWidget {
  final CommissionService commissionService;

  const _CommissionAnalyticsTab({required this.commissionService});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Commission Analytics',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          Expanded(
            child: Center(
              child: Text(
                  'Commission analytics charts and insights will be implemented here.'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommissionPayoutsTab extends StatefulWidget {
  final CommissionService commissionService;

  const _CommissionPayoutsTab({required this.commissionService});

  @override
  State<_CommissionPayoutsTab> createState() => _CommissionPayoutsTabState();
}

class _CommissionPayoutsTabState extends State<_CommissionPayoutsTab> {
  PayoutStatus? _selectedStatus;
  final PayoutService _payoutService = PayoutService();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Vendor Payouts',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              _buildStatusFilter(),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _processScheduledPayouts,
                icon: const Icon(Icons.schedule, size: 18),
                label: const Text('Process Scheduled'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Payout Analytics Cards
          FutureBuilder<PayoutAnalytics>(
            future: _payoutService.getPayoutAnalytics(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return _buildPayoutAnalyticsCards(snapshot.data!);
              }
              return const SizedBox.shrink();
            },
          ),
          const SizedBox(height: 24),

          // Payout Requests List
          Expanded(
            child: FutureBuilder<List<PayoutRequest>>(
              future:
                  _payoutService.getAllPayoutRequests(status: _selectedStatus),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No payout requests found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final payout = snapshot.data![index];
                    return _buildPayoutCard(context, payout);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<PayoutStatus?>(
        value: _selectedStatus,
        hint: const Text('All Statuses'),
        underline: const SizedBox.shrink(),
        items: [
          const DropdownMenuItem<PayoutStatus?>(
            value: null,
            child: Text('All Statuses'),
          ),
          ...PayoutStatus.values.map((status) => DropdownMenuItem(
                value: status,
                child: Text(status.displayName),
              )),
        ],
        onChanged: (status) {
          setState(() {
            _selectedStatus = status;
          });
        },
      ),
    );
  }

  Widget _buildPayoutAnalyticsCards(PayoutAnalytics analytics) {
    return Row(
      children: [
        Expanded(
          child: _buildAnalyticsCard(
            'Total Payouts',
            '₮${analytics.totalPayouts.toStringAsFixed(2)}',
            Icons.account_balance_wallet,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildAnalyticsCard(
            'Pending',
            '₮${analytics.pendingPayouts.toStringAsFixed(2)}',
            Icons.schedule,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildAnalyticsCard(
            'Completed',
            '₮${analytics.completedPayouts.toStringAsFixed(2)}',
            Icons.check_circle,
            Colors.green,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildAnalyticsCard(
            'Success Rate',
            '${analytics.successRate.toStringAsFixed(1)}%',
            Icons.trending_up,
            Colors.purple,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildAnalyticsCard(
            'Platform Fees',
            '₮${analytics.platformFeesCollected.toStringAsFixed(2)}',
            Icons.monetization_on,
            Colors.teal,
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayoutCard(BuildContext context, PayoutRequest payout) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        _getPayoutStatusColor(payout.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getPayoutStatusIcon(payout.status),
                    color: _getPayoutStatusColor(payout.status),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payout Request',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'ID: ${payout.id.substring(0, 8)}...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Chip(
                  label: Text(payout.status.displayName),
                  backgroundColor:
                      _getPayoutStatusColor(payout.status).withOpacity(0.1),
                  labelStyle: TextStyle(
                    color: _getPayoutStatusColor(payout.status),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 12),
                PopupMenuButton<String>(
                  itemBuilder: (context) => [
                    if (payout.status.isPending) ...[
                      const PopupMenuItem(
                        value: 'approve',
                        child: Row(
                          children: [
                            Icon(Icons.check, size: 18, color: Colors.green),
                            SizedBox(width: 8),
                            Text('Approve'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'reject',
                        child: Row(
                          children: [
                            Icon(Icons.close, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Reject'),
                          ],
                        ),
                      ),
                    ],
                    const PopupMenuItem(
                      value: 'details',
                      child: Row(
                        children: [
                          Icon(Icons.info, size: 18),
                          SizedBox(width: 8),
                          Text('View Details'),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) =>
                      _handlePayoutAction(context, payout, value),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Payout Details
            Row(
              children: [
                Expanded(
                  child: _buildPayoutDetail(
                      'Amount', '₮${payout.amount.toStringAsFixed(2)}'),
                ),
                Expanded(
                  child: _buildPayoutDetail('Platform Fee',
                      '₮${payout.platformFee.toStringAsFixed(2)}'),
                ),
                Expanded(
                  child: _buildPayoutDetail(
                      'Net Amount', '₮${payout.netAmount.toStringAsFixed(2)}'),
                ),
                Expanded(
                  child:
                      _buildPayoutDetail('Method', payout.method.displayName),
                ),
                Expanded(
                  child: _buildPayoutDetail(
                    'Requested',
                    _formatDate(payout.requestDate),
                  ),
                ),
              ],
            ),

            if (payout.notes != null && payout.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.note, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        payout.notes!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (payout.failureReason != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, size: 16, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Failure reason: ${payout.failureReason}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPayoutDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Color _getPayoutStatusColor(PayoutStatus status) {
    switch (status) {
      case PayoutStatus.pending:
      case PayoutStatus.scheduled:
        return Colors.orange;
      case PayoutStatus.processing:
        return Colors.blue;
      case PayoutStatus.completed:
        return Colors.green;
      case PayoutStatus.failed:
      case PayoutStatus.cancelled:
        return Colors.red;
      case PayoutStatus.disputed:
        return Colors.purple;
    }
  }

  IconData _getPayoutStatusIcon(PayoutStatus status) {
    switch (status) {
      case PayoutStatus.pending:
        return Icons.schedule;
      case PayoutStatus.scheduled:
        return Icons.event;
      case PayoutStatus.processing:
        return Icons.sync;
      case PayoutStatus.completed:
        return Icons.check_circle;
      case PayoutStatus.failed:
      case PayoutStatus.cancelled:
        return Icons.error;
      case PayoutStatus.disputed:
        return Icons.warning;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _handlePayoutAction(
      BuildContext context, PayoutRequest payout, String action) {
    switch (action) {
      case 'approve':
        _approvePayout(context, payout);
        break;
      case 'reject':
        _rejectPayout(context, payout);
        break;
      case 'details':
        _showPayoutDetails(context, payout);
        break;
    }
  }

  void _approvePayout(BuildContext context, PayoutRequest payout) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Payout'),
        content: Text(
            'Approve payout of ₮${payout.netAmount.toStringAsFixed(2)} to vendor?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _payoutService.processPayoutRequest(
                  payout.id,
                  status: PayoutStatus.completed,
                );
                Navigator.of(context).pop();
                setState(() {}); // Refresh the list
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Payout approved successfully')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error approving payout: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  void _rejectPayout(BuildContext context, PayoutRequest payout) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Payout'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Reject payout of ₮${payout.netAmount.toStringAsFixed(2)}?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _payoutService.processPayoutRequest(
                  payout.id,
                  status: PayoutStatus.failed,
                  failureReason: reasonController.text,
                );
                Navigator.of(context).pop();
                setState(() {}); // Refresh the list
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Payout rejected')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error rejecting payout: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  void _showPayoutDetails(BuildContext context, PayoutRequest payout) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Payout Details - ${payout.id.substring(0, 8)}...'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Vendor ID', payout.vendorId),
              _buildDetailRow('Store ID', payout.storeId),
              _buildDetailRow('Amount', '₮${payout.amount.toStringAsFixed(2)}'),
              _buildDetailRow(
                  'Platform Fee', '₮${payout.platformFee.toStringAsFixed(2)}'),
              _buildDetailRow(
                  'Net Amount', '₮${payout.netAmount.toStringAsFixed(2)}'),
              _buildDetailRow('Method', payout.method.displayName),
              _buildDetailRow('Status', payout.status.displayName),
              _buildDetailRow('Requested', payout.requestDate.toString()),
              if (payout.processedDate != null)
                _buildDetailRow('Processed', payout.processedDate.toString()),
              if (payout.bankAccount != null)
                _buildDetailRow('Bank Account', payout.bankAccount!),
              if (payout.mobileWallet != null)
                _buildDetailRow('Mobile Wallet', payout.mobileWallet!),
              if (payout.notes != null) _buildDetailRow('Notes', payout.notes!),
              if (payout.failureReason != null)
                _buildDetailRow('Failure Reason', payout.failureReason!),
              _buildDetailRow(
                  'Transactions', '${payout.transactionIds.length} included'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Future<void> _processScheduledPayouts() async {
    try {
      final processedPayouts = await _payoutService.processScheduledPayouts();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Processed ${processedPayouts.length} scheduled payouts'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {}); // Refresh the list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing scheduled payouts: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
